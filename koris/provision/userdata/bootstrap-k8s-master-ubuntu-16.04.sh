#!/bin/bash

###
# A script to create a HA K8S cluster on OpenStack using pure bash and kubeadm
###

set -e

# TODO: add /etc/kubernetes/cloud.conf via cloud_init.py
#       uncomment the appropriate section in each file

# all the variables here should be writen to /etc/kubernetes/koris.env
# via cloud_init.py

declare -A MASTERS
declare -A HOSTS
MASTERS["master-1-a"]="de-nbg6-1a"
MASTERS["master-2-a"]="de-nbg6-1a"
MASTERS["master-3-b"]="de-nbg6-1b"
HOSTS["worker-1-a"]="de-nbg6-1a"
HOSTS["worker-2-a"]="de-nbg6-1a"
HOSTS["worker-3-a"]="de-nbg6-1a"
HOSTS["worker-4-b"]="de-nbg6-1b"
HOSTS["worker-5-b"]="de-nbg6-1b"
HOSTS["worker-6-b"]="de-nbg6-1b"
export HOSTS
export IMAGE=koris-2018-11-24
export MASTER_FLAVOR=ECS.C1.2-4
export WORKER_FLAVOR=ECS.C1.4-8
export SUBNET="k8s-subnet"
export FLOATING_IP="213.95.155.150"
export MASTER1_IP=192.168.0.121
export MASTER2_IP=192.168.0.126
export MASTER3_IP=192.168.0.123
export LOAD_BALANCER_IP=213.95.155.150
export LOAD_BALANCER_PORT=6443
export CP0_IP=192.168.0.121
export CP1_IP=192.168.0.126
export CP2_IP=192.168.0.123
export CP0_HOSTNAME=master-1-a
export CP1_HOSTNAME=master-2-a
export CP2_HOSTNAME=master-3-b
export POD_SUBNET=10.233.0.0/16
export KUBE_VERSION=1.11.4
export CLUSTER=master-3-b=https://192.168.0.123:2380,master-1-a=https://192.168.0.121:2380,master-2-a=https://192.168.0.126:2380
export CONTROL_PLANE_IPS="master-2-a master-3-b"
export ALLHOSTS=( "${!HOSTS[@]}" "${!MASTERS[@]}" )
KUBE_VERSION=1.11.4

################################################################################

# writes /etc/kubernetes/cloud.conf
# we can throw this away once cloud_init.py is working again
function write_cloud_conf() {

PY_CODE=$(cat <<END
from openstack.config.loader import _get_os_environ

def env_to_cloud_conf(os_env_dict):
    d = {}
    d['domain-name'] = os_env_dict['user_domain_name']
    d['region'] = os_env_dict['region_name']
    d['tennat-id'] = os_env_dict['project_id']
    d['auth-url'] = os_env_dict['auth_url']
    d['password'] = os_env_dict['password']
    d['username'] = os_env_dict['username']
    return d

with open("cloud.conf", "w") as conf:
    conf.write("[Global]\n" + "\n".join(
        "%s=%s" % (k, v) for (k, v) in env_to_cloud_conf(
            _get_os_environ("OS_")).items()))
END)

python3 -c "$PYTHON_CODE"
mv -v cloud.conf /etc/kubernetes/cloud.conf
}


function write_kubeadm_cfg() {
cat << EOF > kubeadm-master-1.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v${KUBE_VERSION}
apiServerCertSANs:
- "${LOAD_BALANCER_DNS:-${LOAD_BALANCER_IP}}"
api:
    controlPlaneEndpoint: "${LOAD_BALANCER_DNS:-${LOAD_BALANCER_IP}}:${LOAD_BALANCER_PORT}"
etcd:
  local:
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://${CP0_IP}:2379"
      advertise-client-urls: "https://${CP0_IP}:2379"
      listen-peer-urls: "https://${CP0_IP}:2380"
      initial-advertise-peer-urls: "https://${CP0_IP}:2380"
      initial-cluster: "${CP0_HOSTNAME}=https://${CP0_IP}:2380"
    serverCertSANs:
      - ${CP0_HOSTNAME}
      - ${CP0_IP}
    peerCertSANs:
      - ${CP0_HOSTNAME}
      - ${CP0_IP}
networking:
    # This CIDR is a Calico default. Substitute or remove for your CNI provider.
    podSubnet: ${POD_SUBNET}
# TODO: write cloud.conf
#nodeRegistrationOptions:
#  kubeletExtraArgs:
#    cloud-provider: openstack
#    cloud-config: etc/kubernetes/cloud.conf
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: foobar.fedcba9876543210
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
EOF

cat << EOF > kubeadm-master-2.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v${KUBE_VERSION}
apiServerCertSANs:
- "${LOAD_BALANCER_DNS:-${LOAD_BALANCER_IP}}"
api:
    controlPlaneEndpoint: "${LOAD_BALANCER_DNS:-${LOAD_BALANCER_IP}}:${LOAD_BALANCER_PORT}"
etcd:
  local:
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://${CP1_IP}:2379"
      advertise-client-urls: "https://${CP1_IP}:2379"
      listen-peer-urls: "https://${CP1_IP}:2380"
      initial-advertise-peer-urls: "https://${CP1_IP}:2380"
      initial-cluster: "${CP0_HOSTNAME}=https://${CP0_IP}:2380,${CP1_HOSTNAME}=https://${CP1_IP}:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - ${CP1_HOSTNAME}
      - ${CP1_IP}
    peerCertSANs:
      - ${CP1_HOSTNAME}
      - ${CP1_IP}
networking:
    # This CIDR is a calico default. Substitute or remove for your CNI provider.
    podSubnet:  "${POD_SUBNET}"
# TODO: write cloud.conf
#nodeRegistrationOptions:
#  kubeletExtraArgs:
#    cloud-provider: openstack
#    cloud-config: etc/kubernetes/cloud.conf
bootstrapTokens:
EOF

cat << EOF > kubeadm-master-3.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v${KUBE_VERSION}
apiServerCertSANs:
- "${LOAD_BALANCER_DNS:-${LOAD_BALANCER_IP}}"
api:
    controlPlaneEndpoint: "${LOAD_BALANCER_DNS:-${LOAD_BALANCER_IP}}:${LOAD_BALANCER_PORT}"
etcd:
  local:
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://${CP2_IP}:2379"
      advertise-client-urls: "https://${CP2_IP}:2379"
      listen-peer-urls: "https://${CP2_IP}:2380"
      initial-advertise-peer-urls: "https://${CP2_IP}:2380"
      initial-cluster: "${CP0_HOSTNAME}=https://${CP0_IP}:2380,${CP1_HOSTNAME}=https://${CP1_IP}:2380,${CP2_HOSTNAME}=https://${CP2_IP}:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - ${CP2_HOSTNAME}
      - ${CP2_IP}
    peerCertSANs:
      - ${CP2_HOSTNAME}
      - ${CP2_IP}
networking:
    # This CIDR is a calico default. Substitute or remove for your CNI provider.
    podSubnet:  "${POD_SUBNET}"
# TODO: write cloud.conf
#nodeRegistrationOptions:
#  kubeletExtraArgs:
#    cloud-provider: openstack
#    cloud-config: etc/kubernetes/cloud.conf
bootstrapTokens:
EOF
}

# distributes configuration files and certificates
function distribute_keys() {
   USER=ubuntu # customizable
   for host in ${CONTROL_PLANE_IPS}; do
       ssh -i /home/ubuntu/.ssh/id_rsa ${USER}@$host sudo rm -vRf /etc/kubernetes
       ssh -i /home/ubuntu/.ssh/id_rsa  ${USER}@$host mkdir -pv kubernetes/pki/etcd
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/pki/ca.crt "${USER}"@$host:~/kubernetes/pki/
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/pki/ca.key "${USER}"@$host:~/kubernetes/pki/
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/pki/sa.key "${USER}"@$host:~/kubernetes/pki/
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/pki/sa.pub "${USER}"@$host:~/kubernetes/pki/
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/pki/front-proxy-ca.crt "${USER}"@$host:~/kubernetes/pki/
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/pki/front-proxy-ca.key "${USER}"@$host:~/kubernetes/pki/
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/pki/etcd/ca.crt "${USER}"@$host:~/kubernetes/pki/etcd/
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/pki/etcd/ca.key "${USER}"@$host:~/kubernetes/pki/etcd/
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/admin.conf "${USER}"@$host:~/kubernetes/
       sudo -E scp -i /home/ubuntu/.ssh/id_rsa /etc/kubernetes/cloud.conf "${USER}"@$host:~/kubernetes/

       ssh -i /home/ubuntu/.ssh/id_rsa ${USER}@$host sudo mv -v kubernetes /etc/
       ssh -i /home/ubuntu/.ssh/id_rsa ${USER}@$host sudo chown root:root -vR /etc/kubernetes
       ssh -i /home/ubuntu/.ssh/id_rsa ${USER}@$host sudo chmod 0600 -vR /etc/kubernetes/admin.conf
       ssh -i /home/ubuntu/.ssh/id_rsa ${USER}@$host sudo chmod 0600 -vR /etc/kubernetes/cloud.conf
   done
}

function bootstrap_with_phases() {
   kubeadm -v=6 alpha phase certs all --config $1
   kubeadm -v=8 alpha phase kubelet config write-to-disk --config $1
   kubeadm -v=6 alpha phase kubelet write-env-file --config $1
   kubeadm -v=8 alpha phase kubeconfig kubelet --config $1
   kubeadm -v=8 alpha phase kubeconfig all --config $1
   distribute_keys
   systemctl start kubelet
   kubeadm -v=6 alpha phase etcd local --config $1
   kubeadm -v=8 alpha phase controlplane all --config $1
   kubeadm -v=8 alpha phase mark-master --config $1
   kubeadm -v=8 alpha phase addon kube-proxy --config $1
   kubeadm -v=8 alpha phase addon coredns --config $1
   kubeadm alpha phase bootstrap-token all --config $1
   test -d .kube || mkdir .kube
   sudo cp /etc/kubernetes/admin.conf ~/.kube/config
   chown ubuntu:ubuntu ~/.kube/config
   # this only works if the api is available
   until curl -k --connect-timeout 3  https://${LOAD_BALANCER_DNS:-${LOAD_BALANCER_IP}}:${LOAD_BALANCER_PORT}/api/v1/nodes/foo;
       do echo "api server is not up! trying again ...";
   done
   kubeadm -v=6 alpha phase kubelet config upload  --config $1
   kubectl get nodes
}

function bootstrap_master_2() {
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP1_HOSTNAME sudo kubeadm alpha phase certs all --config  kubeadm-master-2.yaml
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP1_HOSTNAME sudo kubeadm alpha phase kubelet config write-to-disk --config  kubeadm-master-2.yaml
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP1_HOSTNAME sudo kubeadm alpha phase kubelet write-env-file --config  kubeadm-master-2.yaml
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP1_HOSTNAME sudo kubeadm alpha phase kubeconfig kubelet --config  kubeadm-master-2.yaml
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP1_HOSTNAME sudo systemctl start kubelet
   # join the etcd host to the cluster
   sudo kubectl exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP1_HOSTNAME} https://${CP1_IP}:2380
   # launch etcd
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP1_HOSTNAME sudo kubeadm alpha phase etcd local --config  kubeadm-master-2.yaml
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP1_HOSTNAME sudo kubeadm alpha phase kubeconfig all --config  kubeadm-master-2.yaml
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP1_HOSTNAME sudo kubeadm alpha phase controlplane all --config   kubeadm-master-2.yaml
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP1_HOSTNAME sudo kubeadm alpha phase mark-master --config  kubeadm-master-2.yaml
}

function bootstrap_master_3() {
    ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP2_HOSTNAME sudo kubeadm alpha phase certs all --config kubeadm-master-3.yaml
    ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP2_HOSTNAME sudo kubeadm alpha phase kubelet config write-to-disk --config kubeadm-master-3.yaml
    ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP2_HOSTNAME sudo kubeadm alpha phase kubelet write-env-file --config kubeadm-master-3.yaml
    ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP2_HOSTNAME sudo kubeadm alpha phase kubeconfig kubelet --config kubeadm-master-3.yaml
    ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP2_HOSTNAME sudo systemctl start kubelet

    sudo kubectl exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP2_HOSTNAME} https://${CP2_IP}:2380

    ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP2_HOSTNAME sudo kubeadm alpha phase etcd local --config kubeadm-master-3.yaml
    ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP2_HOSTNAME sudo kubeadm alpha phase kubeconfig all --config kubeadm-master-3.yaml
    ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP2_HOSTNAME sudo kubeadm alpha phase controlplane all --config kubeadm-master-3.yaml
    ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP2_HOSTNAME sudo kubeadm alpha phase mark-master --config kubeadm-master-3.yaml
}

function wait_for_etcd () {
    until [[ x"$(kubectl get pod --selector=component=etcd -n kube-system -o jsonpath='{.items[0].status.phase}')" == x"Running" ]]; do
        echo "waiting ..."
        sleep 2
    done
}

set -x

write_kubeadm_cfg

scp -i /home/ubuntu/.ssh/id_rsa kubeadm-master-2.yaml ubuntu@master-2-a:~/
scp -i /home/ubuntu/.ssh/id_rsa kubeadm-master-3.yaml ubuntu@master-3-b:~/

write_cloud_conf
bootstrap_with_phases kubeadm-master-1.yaml
wait_for_etcd
bootstrap_master_2
bootstrap_master_3

# add calico! we should have these manifests in the base image
# this will prevent failure if there is a network problem
curl -O https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
curl -O https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

sed "s@192.168.0.0/16@"${POD_SUBNET}"@g" calico.yaml

kubectl apply -f rbac-kdd.yaml
kubectl apply -f calico.yaml
