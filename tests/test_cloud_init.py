import base64
import re
import uuid
import yaml

from kolt.cloud import CloudInit
from kolt.kolt import create_certs
from kolt.util import (EtcdHost, EtcdCertBundle,
                       ServiceAccountCertBundle, OSCloudConfig)


test_cluster = [EtcdHost("master-%d-k8s" % i,
                         "10.32.192.10%d" % i) for i in range(1, 4)]

etcd_host_list = test_cluster

hostnames, ips = map(list, zip(*[(i.name, i.ip_address) for
                                 i in etcd_host_list]))


cloud_config = OSCloudConfig(user="serviceuser", password="s9kr9t",
                             auth_url="keystone.myopenstack.de",
                             tenant_id="c869168a828847f39f7f06edd7305637",
                             domain_id="2a73b8f597c04551a0fdc8e95544be8a")

(_, ca_cert, k8s_key, k8s_cert,
 svc_accnt_key, svc_accnt_cert) = create_certs({},
                                               hostnames, ips, write=False)
etcd_cert_bundle = EtcdCertBundle(ca_cert, k8s_key, k8s_cert)
svc_accnt_cert_bundle = ServiceAccountCertBundle(svc_accnt_key, svc_accnt_cert)

encryption_key = base64.b64encode(uuid.uuid4().hex[:32].encode()).decode()


def test_cloud_init():
    ci = CloudInit("master", "master-1-k8s", test_cluster,
                   cert_bundle=(etcd_cert_bundle, svc_accnt_cert_bundle),
                   encryption_key=encryption_key,
                   cloud_provider=cloud_config)

    config = ci.get_files_config()
    config = yaml.load(config)

    assert len(config['write_files']) == 8

    etcd_host = test_cluster[0]

    etcd_env = [i for i in config['write_files'] if
                i['path'] == '/etc/systemd/system/etcd.env'][0]

    assert re.findall("%s=https://%s:%s" % (
        etcd_host.name, etcd_host.ip_address, etcd_host.port),
        etcd_env['content'])
