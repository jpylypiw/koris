"""
Builder
=======

Build a kubernetes cluster on a cloud
"""
import asyncio
import sys

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.backends import default_backend

from koris.provision.cloud_init import FirstMasterInit, NthMasterInit, NodeInit
from koris.ssl import create_key, create_ca, CertBundle
from koris.util.hue import (  # pylint: disable=no-name-in-module
    red, info, lightcyan as cyan)

from koris.util.util import get_logger
from .openstack import OSClusterInfo, BuilderError
from .openstack import (get_clients,
                        OSCloudConfig, LoadBalancer,
                        )

LOGGER = get_logger(__name__)

NOVA, NEUTRON, CINDER = get_clients()


class NodeBuilder:
    """
    Interact with openstack and create a virtual machines with a volume,
    and network interface. The machines are provisioned with cloud-init.

    Args:
        nova (nova client instance) - to create a volume and a machine
        neutron (neutron client instance) - to create a network interface
        config (dict) - the parsed configuration file
    """
    def __init__(self, config, osinfo):
        LOGGER.info(info(cyan(
            "gathering node information from openstack ...")))
        self.config = config
        self._info = osinfo

    def get_nodes(self):
        """
        get information on the nodes from openstack.

        Return:
            list [openstack.Instance, openstack.Instance, ...]
        """

        return list(self._info.distribute_nodes())

    def create_nodes_tasks(self, ca_bundle, lb_ip, lb_port, bootstrap_token,
                           discovery_hash):
        """
        Create future tasks for creating the cluster worker nodes
        """
        nodes = self.get_nodes()

        loop = asyncio.get_event_loop()
        tasks = []

        for node in nodes:
            if node._exists:
                raise BuilderError("Node {} is already existing! Skipping "
                                   "creation of the cluster.".format(node))

            userdata = str(NodeInit(ca_bundle, lb_ip, lb_port, bootstrap_token,
                                    discovery_hash))
            tasks.append(loop.create_task(
                node.create(self._info.node_flavor, self._info.secgroups,
                            self._info.keypair, userdata)
            ))

        return tasks


class ControlPlaneBuilder:
    """
    Interact with openstack and create a virtual machines with a volume,
    and network interface. The machines are provisioned with cloud-init.
    This class builds the control plane machine, and although it is similar
    to NodeBuilder it uses a bit slightly different methods under the hood to
    configure the control plane services.

    Args:
        nova (nova client instance) - to create a volume and a machine
        neutron (neutron client instance) - to create a network interface
        config (dict) - the parsed configuration file
    """

    def __init__(self, config, osinfo):
        LOGGER.info("gathering control plane information from openstack ...")
        self._config = config
        self._info = osinfo

    def get_masters(self):
        """
        get information on the nodes from openstack.

        Return:
            list [openstack.Instance, openstack.Instance, ...]
        """
        return list(self._info.distribute_management())

    def create_masters_tasks(self, ssh_key, ca_bundle, cloud_config, lb_ip,
                             lb_port, bootstrap_token, lb_dns=''):
        """
        Create future tasks for creating the cluster control plane nodesself.
        """
        masters = self.get_masters()
        if len(masters) < 3:
            LOGGER.warn("There should be at lest three master nodes!")
            return

        master_ips = [master.ip_address for master in masters]
        master_names = [master.name for master in masters]

        loop = asyncio.get_event_loop()
        tasks = []

        for index, master in enumerate(masters):
            if master._exists:
                raise BuilderError("Node {} is already existing! Skipping "
                                   "creation of the cluster.".format(master))

            if not index:
                # create userdata for first master node if not existing
                userdata = str(FirstMasterInit(ssh_key, ca_bundle,
                               cloud_config, master_ips, master_names, lb_ip,
                               lb_port, bootstrap_token, lb_dns))
            else:
                # create userdata for following master nodes if not existing
                userdata = str(NthMasterInit(ssh_key))

            tasks.append(loop.create_task(
                master.create(self._info.master_flavor, self._info.secgroups,
                              self._info.keypair, userdata)
            ))

        return tasks


class ClusterBuilder:  # pylint: disable=too-few-public-methods

    """
    Plan and build a kubernetes cluster in the cloud
    """
    def __init__(self, config):
        if not (config['n-etcds'] % 2 and config['n-etcds'] > 1):
            print(red("You must have an odd number (>1) of etcd machines!"))
            sys.exit(2)

        self.info = OSClusterInfo(NOVA, NEUTRON, CINDER, config)
        LOGGER.debug(info("Done collecting information from OpenStack"))

        self.nodes_builder = NodeBuilder(config, self.info)
        self.masters_builder = ControlPlaneBuilder(config, self.info)

    @staticmethod
    def create_ca():
        """create a self signed CA"""
        _key = create_key(size=2048)
        _ca = create_ca(_key, _key.public_key(),
                        "DE", "BY", "NUE",
                        "Kubernetes", "CDA-RT",
                        "kubernetes-ca")
        return CertBundle(_key, _ca)

    def run(self, config):  # pylint: disable=too-many-locals
        """
        execute the complete cluster build
        """
        if not config['subnet']:
            LOGGER.error("You must specify a subnet ID.")
            return

        # create a security group for the cluster if not already present
        if self.info.secgroup._exists:
            LOGGER.info(info(red(
                "A Security group named %s-sec-group already exists" % config[
                    'cluster-name'])))
            LOGGER.info(
                info(red("I will add my own rules, please manually review all others")))  # noqa

        self.info.secgroup.configure()

        cloud_config = OSCloudConfig(config['subnet'])

        # generate CA key pair for the cluster, that is used to authenticate
        # the clients that can use kubeadm
        ca_bundle = self.create_ca()
        cert_dir = "-".join(("certs", config["cluster-name"]))
        ca_bundle.save("k8s", cert_dir)

        # generate ssh key pair for first master node. It is used to connect
        # to the other nodes so that they can join the cluster
        ssh_key = create_key()

        # create a load balancer for accessing the API server of the cluster;
        # do not add a listener, since we created no machines yet.
        LOGGER.info("Creating the load balancer...")
        lbinst = LoadBalancer(config)
        lb, floatingip = lbinst.get_or_create(NEUTRON)
        lb_port = "6443"  # TODO: Where to get port from?
        lb_dns = ""  # TODO: get this clean?

        # calculate information needed for joining nodes to the cluster...
        # calculate bootstrap token
        # TODO: generate generic bootstrap token
        bootstrap_token = "foobar.fedcba9876543210"

        # calculate discovery hash
        pub_key = ca_bundle.cert.public_key()
        digest = hashes.Hash(hashes.SHA256(), backend=default_backend())
        digest.update(pub_key.public_bytes(
            serialization.Encoding.DER,
            format=serialization.PublicFormat.SubjectPublicKeyInfo))
        discovery_hash = digest.finalize().hex()

        # create the master nodes with ssh_key (private and public key)
        # first task in returned list is task for first master node
        LOGGER.info("Waiting for the master machines to be launched...")
        master_tasks = self.masters_builder.create_masters_tasks(
            ssh_key, ca_bundle, cloud_config, floatingip, lb_port,
            bootstrap_token, lb_dns)
        loop = asyncio.get_event_loop()
        results = loop.run_until_complete(asyncio.gather(*master_tasks))

        # add a listener for the first master node, since this is the node we
        # call kubeadm init on
        LOGGER.info("Configuring the LoadBalancer...")
        first_master_ip = results[0].ip_address
        configure_lb_task = loop.create_task(
            lbinst.configure(NEUTRON, [first_master_ip]))
        results = loop.run_until_complete(asyncio.gather(configure_lb_task))

        # create the worker nodes
        LOGGER.info("Waiting for the worker machines to be launched...")
        node_tasks = self.nodes_builder.create_nodes_tasks(
            ca_bundle, floatingip, lb_port, bootstrap_token, discovery_hash)
        results = loop.run_until_complete(asyncio.gather(*node_tasks))

        # We should no be able to query the API server for available nodes
        # with a valid certificate from the generated CA. Hence, generate
        # a client certificate and connect the the API server and query which
        # nodes are available. If every node is available and running, continue
        LOGGER.info("Talking to the API server and waiting for nodes to be "
                    "online.")
        # Finally, we want to add the other master nodes to the LoadBalancer
        LOGGER.info("Configuring load balancer again...")
        masters = [master.result() for master in master_tasks]
        for master in masters:
            lbinst.add_member(NEUTRON, lbinst.pool['id'], master.ip_address)
        results = loop.run_until_complete(asyncio.gather(configure_lb_task))

        # At this point, we're ready with our cluster
        LOGGER.debug(info("Done creating nodes tasks"))
        LOGGER.info("Kubernetes API Server is ready !!!")
