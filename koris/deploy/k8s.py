"""
deploy cluster service to kubernetes via the API server
"""
import base64
from datetime import datetime, timedelta
import getpass
import logging
import os
import random
import socket
import string
import sys
import urllib3

from pkg_resources import resource_filename, Requirement

from kubernetes import (client as k8sclient, config as k8sconfig)

from koris.ssl import read_cert, discovery_hash
from koris.util.util import get_logger

if getattr(sys, 'frozen', False):
    MANIFESTSPATH = os.path.join(
        sys._MEIPASS,  # pylint: disable=no-member, protected-access
        'koris/deploy/manifests')
else:
    MANIFESTSPATH = resource_filename(Requirement.parse("koris"),
                                      'koris/deploy/manifests')

LOGGER = get_logger(__name__, level=logging.DEBUG)


def rand_string(num):
    """
    generate a random string of len num
    """
    return ''.join([
        random.choice(string.ascii_letters.lower() + string.digits)
        for n in range(num)])


def get_token_description():
    """create a description for the token"""

    description = "Bootstrap token generated by 'koris add' from {} on {}"

    return description.format('%s@%s' % (getpass.getuser(), socket.gethostname()),
                              datetime.now())


class K8S:
    """
    Deploy basic service to the cluster

    This class is responsible of starting the CNI layer (calico) and
    the DNS service (kube-dns)

    """
    def __init__(self, config, manifest_path=None):

        self.config = config
        if not manifest_path:
            manifest_path = MANIFESTSPATH
        self.manifest_path = manifest_path
        k8sconfig.load_kube_config(config)
        self.api = k8sclient.CoreV1Api()

    def get_bootstrap_token(self):
        """
        Generate a Bootstrap token
        """
        tid = rand_string(6)
        token_secret = rand_string(16)
        data = {'description': get_token_description(),
                'token-id': tid,
                'token-secret': token_secret,
                'expiration':
                datetime.strftime(datetime.now() + timedelta(hours=2),
                                  "%Y-%m-%dT%H:%M:%SZ"),
                'usage-bootstrap-authentication': 'true',
                'usage-bootstrap-signing': 'true',
                'auth-extra-groups':
                'system:bootstrappers:kubeadm:default-node-token', }

        for k, val in data.items():
            data[k] = base64.b64encode(val.encode()).decode()
        sec = k8sclient.V1Secret(data=data)
        sec.metadata = k8sclient.V1ObjectMeta(
            **{'name': 'bootstrap-token-%s' % tid, 'namespace': 'kube-system'})
        sec.type = 'bootstrap.kubernetes.io/token'

        self.api.create_namespaced_secret(namespace="kube-system", body=sec)
        return ".".join((tid, token_secret))

    @property
    def host(self):
        """retrieve the host or loadbalancer info"""
        return self.api.api_client.configuration.host

    @property
    def ca_info(self):
        """return a dict with the read ca and the discovery hash"""
        return {"ca_cert": self.ca_cert, "discovery_hash": self.discovery_hash}

    @property
    def ca_cert(self):
        """
        retrun the CA as b64 string
        """
        return read_cert(self.api.api_client.configuration.ssl_ca_cert)

    @property
    def discovery_hash(self):
        """
        calculate and return a discovery_hash based on the cluster CA
        """
        return discovery_hash(self.ca_cert)

    @property
    def is_ready(self):
        """
        check if the API server is already available
        """
        logging.getLogger("urllib3").setLevel(logging.ERROR)
        try:
            k8sclient.apis.core_api.CoreApi().get_api_versions()
            logging.getLogger("urllib3").setLevel(logging.WARNING)
            return True
        except urllib3.exceptions.MaxRetryError:
            logging.getLogger("urllib3").setLevel(logging.WARNING)
            return False

    def add_all_masters_to_loadbalancer(self,
                                        n_masters,
                                        lb_inst,
                                        neutron_client
                                        ):
        """
        If we find at least one node that has no Ready: True, return False.
        """
        cond = {'Ready': 'True'}
        while len(lb_inst.members) < n_masters:
            for item in self.api.list_node(pretty=True).items:
                if cond in [{c.type: c.status} for c in item.status.conditions]:
                    if 'master' in item.metadata.name:
                        address = item.status.addresses[0].address
                        if address not in lb_inst.members:
                            lb_inst.add_member(neutron_client, lb_inst.pool,
                                               address)
                            LOGGER.info(
                                "Added member no. %d %s to the loadbalancer",
                                len(lb_inst.members), address)
