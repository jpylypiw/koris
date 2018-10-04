import base64
import copy
import logging
import textwrap

from configparser import ConfigParser
from functools import lru_cache
from ipaddress import IPv4Address

import yaml


def get_logger(name):
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    # add ch to logger
    logger.addHandler(ch)
    return logger


class NodeZoneNic:

    """
    A Simple data class for holding information about a host
    """

    def __init__(self, name, zone, nic=None):
        self.name = name
        self.zone = zone
        self.nic = nic

    @classmethod
    def hosts_distributor(cls, hosts_zones):
        for item in hosts_zones:
            hosts, zone = item[0], item[1]
            for host in hosts:
                yield cls(host, zone, None)

    def __repr__(self):

        return "<%s@%s>" % (self.name, self.zone)


def distribute_hosts(hosts_zones):
    """
    Distribute hosts through availability zones

    Args:
        hosts_zones (list) - a list of tuples with hosts names and zones

        [(['host1', 'host2', 'host3'], 'A'), (['host4', 'host5'], 'B')]

    Return:
        list in the form

        [(host1, zone), (host2, zone), ... (host4, zone), (host5, zone)]
    """
    for item in hosts_zones:
        hosts, zone = item[0], item[1]
        for host in hosts:
            yield [host, zone, None]


def get_host_zones(hosts, zones):
    # brain fuck warning
    # this divides the lists of hosts into zones
    # >>> hosts
    # >>> ['host1', 'host2', 'host3', 'host4', 'host5']
    # >>> zones
    # >>> ['A', 'B']
    # >>> list(zip([hosts[i:i + n] for i in range(0, len(hosts), n)], zones)) # noqa
    # >>> [(['host1', 'host2', 'host3'], 'A'), (['host4', 'host5'], 'B')]  # noqa
    if len(zones) == len(hosts):
        return list(zip(hosts, zones))
    else:
        end = len(zones) + 1 if len(zones) % 2 else len(zones)
        host_zones = list(zip([hosts[i:i + end] for i in
                               range(0, len(hosts), end)],
                              zones))
        return NodeZoneNic.hosts_distributor(host_zones)


class Server:

    def __init__(self, name, nics, server=None):

        self.name = name
        self._interface_list = nics
        self._nova_server = server

    def interface_list(self):
        return self._interface_list

    @property
    def ip_address(self):
        try:
            return self._interface_list[0].fixed_ips[0]['ip_address']
        except AttributeError:
            return self._interface_list[0]['port']['fixed_ips'][0]['ip_address']  # noqa

    def connection_uri(self, port, protocol="https"):
        return "%s://%s:%d" % (protocol, self.ip_address, port)


class EtcdHost:

    def __init__(self, name, ip_address, port=2380):
        self.name = name
        self.ip_address = IPv4Address(ip_address)
        self.port = port

    def _connection_uri(self):
        return "%s=https://%s:%d" % (self.name, self.ip_address, self.port)

    def __str__(self):
        return self._connection_uri()


encryption_config_tmpl = """
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: %%ENCRYPTION_KEY%%
      - identity: {}
"""

kubeconfig = {'apiVersion': 'v1',
              'clusters': [
                  {'cluster': {'insecure-skip-tls-verify': True,
                               'server': '%%%%MASTERURI%%%',
                               'certificate-authority':
                               '/var/lib/kubernetes/ca.pem'},
                   'name': 'kubernetes'}],
              'contexts': [
                  {'context':
                      {'cluster': 'kubernetes',
                       'user': '%%%USERNAME%%%'},
                   'name': '%%%USERNAME%%%-context'}],
              'current-context': '%%%USERNAME%%%-context',
              'kind': 'Config',
              'users': [
                  {'name': '%%%USERNAME%%%',
                   'user': {'token': '%%%USERTOKEN%%%'}
                   }]
              }


def get_kubeconfig_yaml(master_uri, username, token,
                        skip_tls=False,
                        encode=True,
                        ca="/var/lib/kubernetes/ca.pem"):
    config = copy.deepcopy(kubeconfig)
    if skip_tls:
        config['clusters'][0]['cluster'].pop('insecure-skip-tls-verify')
        config['clusters'][0]['cluster']['server'] = master_uri
        config['clusters'][0]['cluster']['certificate-authority'] = ca
    else:
        config['clusters'][0]['cluster'].pop('server')

    config['contexts'][0]['name'] = "%s-context" % username
    config['contexts'][0]['context']['user'] = "%s" % username
    config['current-context'] = "%s-context" % username
    config['users'][0]['name'] = username
    config['users'][0]['user']['token'] = token

    yml_config = yaml.dump(config)

    if encode:
        yml_config = base64.b64encode(yml_config.encode()).decode()
    return yml_config


calicoconfig = {
    "name": "calico-k8s-network",
    "type": "calico",
    "datastore_type": "etcdv3",
    "log_level": "DEBUG",
    "etcd_endpoints": "",
    "etcd_key_file": "/var/lib/kubernetes/kubernetes-key.pem",
    "etcd_cert_file": "/var/lib/kubernetes/kubernetes.pem",
    "etcd_ca_cert_file": "/var/lib/kubernetes/ca.pem",
    "ipam": {
        "type": "calico-ipam",
        "assign_ipv4": "true",
        "assign_ipv6": "false",
        "ipv4_pools": ["10.233.0.0/16"]
    },
    "policy": {
        "type": "k8s"
    },
    "nodename": "__NODENAME__"  # <- This is replaced during boot
}

#    "kubernetes": {
#        "kubeconfig": "/etc/calico/kube/kubeconfig"
#    }


def get_node_info_from_openstack(config, nova, role):
    # find all servers in my cluster which are etcd or master
    cluster_suffix = "-%s" % config['cluster-name']

    servers = [server for server in nova.servers.list() if
               server.name.endswith(cluster_suffix)]

    servers = [server for server in servers if
               server.name.startswith(role)]

    assert len(servers)

    names = []
    ips = []

    for server in servers:
        names.append(server.name)
        ips.append(server.interface_list()[0].fixed_ips[0]['ip_address'])

    names.append("localhost")
    ips.append("127.0.0.1")

    return names, ips


def get_server_info_from_openstack(config, nova):
    # find all servers in my cluster which are etcd or master
    cluster_suffix = "-%s" % config['cluster-name']

    servers = [server for server in nova.servers.list() if
               server.name.endswith(cluster_suffix)]

    assert len(servers)

    names = []
    ips = []

    for server in servers:
        names.append(server.name)
        ips.append(server.interface_list()[0].fixed_ips[0]['ip_address'])

    names.append("localhost")
    ips.append("127.0.0.1")

    return names, ips


def get_token_csv(adminToken, calicoToken, kubeletToken):
    """
    write the content of
    /var/lib/kubernetes/token.csv
    """
    # TODO: check how to get this working ...
    # {bootstrapToken},kubelet,kubelet,10001,"system:node-bootstrapper"
    content = """
    {adminToken},admin,admin,"cluster-admin,system:masters"
    {calicoToken},calico,calico,"cluster-admin,system:masters"
    {kubeletToken},kubelet,kubelet,"cluster-admin,system:masters"
    """.format(
        adminToken=adminToken,
        calicoToken=calicoToken,
        kubeletToken=kubeletToken,
        bootstrapToken=kubeletToken
    )

    return base64.b64encode(textwrap.dedent(content).encode()).decode()


@lru_cache(maxsize=16)
def host_names(role, num, cluster_name):
    return ["%s-%s-%s" % (role, i, cluster_name) for i in
            range(1, num + 1)]


def create_inventory(hosts, config):
    """
    :hosts:
    :config: config dictionary
    """

    cfg = ConfigParser(allow_no_value=True, delimiters=('\t', ' '))

    [cfg.add_section(item) for item in ["all", "kube-master", "kube-node",
                                        "etcd", "k8s-cluster:children"]]
    masters = []
    nodes = []

    for (host, ip) in hosts.items():
        cfg.set("all", host, "ansible_ssh_host=%s  ip=%s" % (ip, ip))
        if host.startswith("master"):
            cfg.set("kube-master", host)
            masters.append(host)
        if host.startswith("node"):
            cfg.set("kube-node", host)
            nodes.append(host)

    # add etcd
    for master in masters:
        cfg.set("etcd", master)

    etcds_missing = config["n-etcds"] - len(masters)
    for node in nodes[:etcds_missing]:
        cfg.set("etcd", node)

    # add all cluster groups
    cfg.set("k8s-cluster:children", "kube-node")
    cfg.set("k8s-cluster:children", "kube-master")

    return cfg
