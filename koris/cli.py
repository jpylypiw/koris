"""
cli.py
======

misc functions to interact with the cluster, usually called from
``koris.koris.Kolt``.

Don't use directly
"""
import asyncio
import sys

from cinderclient.exceptions import BadRequest, NotFound

from koris.util.hue import que, bold  # pylint: disable=no-name-in-module
from koris.cloud.openstack import OSClusterInfo, LoadBalancer, get_connection
from .util.util import get_kubeconfig_yaml
from .util.logger import Logger

LOGGER = Logger(__name__)


def delete_cluster(config, nova, neutron, cinder, force=False):
    """Completly delete a cluster from openstack.

    This function removes all compute instance, volume, loadbalancer,
    security groups rules and security groups
    """
    if not force:
        ans = input(que(bold("Are you sure? [y/N]: ")))
    else:
        ans = 'y'

    if ans.lower() == 'y':
        conn = get_connection()
        remove_cluster(config, nova, neutron, cinder, conn)
    else:
        sys.exit(1)


def write_kubeconfig(cluster_name, lb_ip, lb_port, ca_cert,
                     client_cert, client_key):
    """Write a kubeconfig file to the filesystem"""

    path = None
    master_uri = "https://" + lb_ip + ":" + lb_port
    username = "admin"

    kubeconfig = get_kubeconfig_yaml(master_uri, ca_cert, username,
                                     client_cert, client_key)

    path = '-'.join((cluster_name, 'admin.conf'))
    LOGGER.success("You can use your config with:")
    LOGGER.success("kubectl get nodes --kubeconfig=%s" % path)
    with open(path, "w") as fh:
        fh.write(kubeconfig)

    return path


# pylint: disable=too-many-locals
def remove_cluster(config, nova, neutron, cinder, conn):
    """Delete a cluster from OpenStack"""

    cluster_info = OSClusterInfo(nova, neutron, cinder, config, conn)
    cp_hosts = cluster_info.distribute_management()
    workers = cluster_info.distribute_nodes()

    tasks = [host.delete(neutron) for host in cp_hosts]
    tasks += [host.delete(neutron) for host in workers]
    loop = asyncio.get_event_loop()
    loop.run_until_complete(asyncio.wait(tasks))

    LoadBalancer(config, conn).delete()
    secg = conn.list_security_groups(
        {"name": '%s-sec-group' % config['cluster-name']})
    if secg:
        for sg in secg:
            for rule in sg.security_group_rules:
                conn.delete_security_group_rule(rule['id'])

            for port in conn.list_ports():
                if sg.id in port.security_groups:
                    conn.delete_port(port.id)
    conn.delete_security_group(
        '%s-sec-group' % config['cluster-name'])

    # Delete volumes
    loop.close()

    # This needs to be replaced with OpenStackAPI in the future
    for vol in cinder.volumes.list():
        try:
            if config['cluster-name'] in vol.name and vol.status != 'in-use':
                try:
                    vol.delete()
                except (BadRequest, NotFound):
                    pass

        except TypeError:
            continue

    # delete the cluster key pair
    conn.delete_keypair(config['cluster-name'])
