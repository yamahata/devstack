#!/usr/bin/env bash

# **neutron-servicevm.sh**

# Test servicevm via the command line

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Keep track of the current directory
EXERCISE_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $EXERCISE_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import configuration
source $TOP_DIR/openrc

# Import exercise configuration
source $TOP_DIR/exerciserc

# Skip if the hypervisor is Docker
[[ "$VIRT_DRIVER" == "docker" ]] && exit 55


# Testing neutron servicevm
# =========================

# wget https://downloads.openwrt.org/barrier_breaker/14.07/x86/kvm_guest/openwrt-x86-kvm_guest-combined-ext4.img.gz
# gunzip openwrt-x86-kvm_guest-combined-ext4.img.gz
# glance image-create --name openwrt-x86 --is-public=True --container-format bare --disk-format raw --property hw_disk_bus=ide --file openwrt-x86-kvm_guest-combined-ext4.img

# create openwrt-x86 image
# http://hackstack.org/x/blog/2014/08/17/openwrt-images-for-openstack/
glance image-create --name OpenWRT --is-public=True --container-format bare --disk-format raw --file /home/yamahata/openstack/tacker/openwrt/bin/x86/openwrt-x86-kvm_guest-combined-ext4.img

# create necessary networks
# prepare network
MGMT_PHYS_NET=mgmtphysnet0
BR_MGMT=br-mgmt0
NET_MGMT=net_mgmt
SUBNET_MGMT=subnet_mgmt
FIXED_RANGE_MGMT=10.253.255.0/24
NETWORK_GATEWAY_MGMT=10.253.255.1
NETWORK_GATEWAY_MGMT_IP=10.253.255.1/24

NET0=net0
SUBNET0=subnet0
FIXED_RANGE0=10.253.0.0/24
NETWORK_GATEWAY0=10.253.0.1

NET1=net1
SUBNET1=subnet1
FIXED_RANGE1=10.253.1.0/24
NETWORK_GATEWAY1=10.253.1.1

NET2=net2
SUBNET2=subnet2
FIXED_RANGE2=10.253.2.0/24
NETWORK_GATEWAY2=10.253.2.1


for net in ${NET_MGMT} ${NET0} ${NET1} ${NET2}
do
    for i in $(neutron net-list | awk "/${net}/{print \$2}")
    do
	neutron net-delete $i
    done
done


NET_MGMT_ID=$(neutron net-create --provider:network_type flat --provider:physical_network ${MGMT_PHYS_NET} --shared ${NET_MGMT} | awk '/ id /{print $4}')
SUBNET_MGMT_ID=$(neutron subnet-create --name ${SUBNET_MGMT} --ip-version 4 --gateway ${NETWORK_GATEWAY_MGMT} ${NET_MGMT_ID} ${FIXED_RANGE_MGMT} | awk '/ id /{print $4}')
NET0_ID=$(neutron net-create --shared ${NET0} | awk '/ id /{print $4}')
SUBNET0_ID=$(neutron subnet-create --name ${SUBNET0} --ip-version 4 --gateway ${NETWORK_GATEWAY0} ${NET0_ID} ${FIXED_RANGE0} | awk '/ id /{print $4}')
NET1_ID=$(neutron net-create --shared ${NET1} | awk '/ id /{print $4}')
SUBNET1_ID=$(neutron subnet-create --name ${SUBNET1} --ip-version 4 --gateway ${NETWORK_GATEWAY1} ${NET1_ID} ${FIXED_RANGE1} | awk '/ id /{print $4}')
NET2_ID=$(neutron net-create --shared ${NET2} | awk '/ id /{print $4}')
SUBNET2_ID=$(neutron subnet-create --name ${SUBNET2} --ip-version 4 --gateway ${NETWORK_GATEWAY2} ${NET2_ID} ${FIXED_RANGE2} | awk '/ id /{print $4}')

echo ${NET_MGMT_ID}
echo ${SUBNET_MGMT_ID}
echo ${NET0_ID}
echo ${SUBNET0_ID}
echo ${NET1_ID}
echo ${SUBNET1_ID}
echo ${NET2_ID}
echo ${SUBNET2_ID}

sudo ifconfig ${BR_MGMT} inet 0.0.0.0
sudo ifconfig ${BR_MGMT} inet ${NETWORK_GATEWAY_MGMT_IP}

VNFD_NAME=vnfd-demo
#VNFD_FILE=/home/yamahata/openstack/tacker/tacker/vnfd-template/vnfd-use-sample2.yaml
#VNFD_ID=$(tacker vnfd-create --name ${VNFD_NAME} --vnfd-file ${VNFD_FILE})
VNFD_DATA=$(cat <<EOF
template_name: sample-vnfd
description: demo-example

service_properties:
  Id: sample-vnfd
  vendor: tacker
  version: 1

vdus:
  vdu1:
    id: vdu1
    vm_image: cirros-0.3.2-x86_64-uec
    instance_type: m1.tiny

    network_interfaces:
      management:
        network: net_mgmt
        management: true
      pkt_in:
        network: net0
      pkt_out:
        network: net1

    placement_policy:
      availability_zone: nova

    auto-scaling: noop
    monitoring_policy: ping
    failure_policy: respawn

    config:
      param0: key0
      param1: key1
EOF
)

VNFD_ID=$(tacker vnfd-create --name ${VNFD_NAME} --vnfd "${VNFD_DATA}" | awk '/ id /{print $4}')


#CONFIG_FILE=/home/yamahata/openstack/tacker/tacker/vnfd-template/config.yaml
#VNF_ID=$(tacker vnf-create --vnfd-id ${VNFD_ID} --config-file ${CONFIG_FILE})
CONFIG_DATA=$(cat <<'EOF'
vdus:
  vdu1:
    config:
      conf0: value0
      conf1: value1
EOF
)

VNF_ID=$(tacker vnf-create --name vnf-name --vnfd-id ${VNFD_ID} --config "${CONFIG_DATA}" | awk '/ id /{print $4}')

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
