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

# List servicevm template
neutron svcvm-device-template-list
neutron svcvm-device-list
neutron svcvm-service-instance-list

# create hosting device template
FLAVOR=m1.tiny
FLAVOR_ID=$(nova flavor-show m1.tiny  | awk '/ id /{print $4}')
IMAGE=cirros-0.3.1-x86_64-uec
IMAGE_ID=$(nova image-show ${IMAGE} | awk '/ id /{print $4}')
NAME=test-servicevm
HOSTING_DEVICE_DRIVER=nova
#MGMT_DRIVER=noop
#MGMT_DRIVER=agent-rpc
MGMT_DRIVER=agent-proxy
SERVICE_TYPE=LOADBALANCER

TEMPLATE_ID=$(neutron svcvm-device-template-create --template-service-type ${SERVICE_TYPE} --device-driver ${HOSTING_DEVICE_DRIVER} --mgmt-driver ${MGMT_DRIVER} --name ${NAME} --attribute flavorRef ${FLAVOR_ID} --attribute imageRef ${IMAGE_ID} --attribute mgmt-network ${NET_MGMT_ID} | awk '/ id /{print $4}')
neutron svcvm-device-template-list
neutron svcvm-device-template-show ${TEMPLATE_ID}
neutron svcvm-device-template-delete ${TEMPLATE_ID}

TEMPLATE_ID=$(neutron svcvm-device-template-create --template-service-type ${SERVICE_TYPE} --device-driver ${HOSTING_DEVICE_DRIVER} --mgmt-driver ${MGMT_DRIVER} --name ${NAME} --attribute flavorRef ${FLAVOR_ID} --attribute imageRef ${IMAGE_ID} | awk '/ id /{print $4}')


neutron svcvm-device-list
#neutron svcvm-device-create

# prepare network
NET_MGMT=net_mgmt
SUBNET_MGMT=subnet_mgmt
FIXED_RANGE_MGMT=10.253.255.0/24
NETWORK_GATEWAY_MGMT=10.253.255.1


NET0=net0
SUBNET0=subnet0
FIXED_RANGE0=10.253.0.0/24
NETWORK_GATEWAY0=10.253.0.1

NET1=net1
SUBNET1=subnet1
FIXED_RANGE1=10.253.1.0/24
NETWORK_GATEWAY1=10.253.1.1

NET_MGMT_ID=$(neutron net-create ${NET_MGMT} | awk '/ id /{print $4}')
SUBNET_MGMT_ID=$(neutron subnet-create --name ${SUBNET_MGMT} --ip-version 4 --gateway ${NETWORK_GATEWAY_MGMT} ${NET_MGMT_ID} ${FIXED_RANGE_MGMT} | awk '/ id /{print $4}')

NET0_ID=$(neutron net-create ${NET0} | awk '/ id /{print $4}')
SUBNET0_ID=$(neutron subnet-create --name ${SUBNET0} --ip-version 4 --gateway ${NETWORK_GATEWAY0} ${NET0_ID} ${FIXED_RANGE0} | awk '/ id /{print $4}')
NET1_ID=$(neutron net-create ${NET1} | awk '/ id /{print $4}')
SUBNET1_ID=$(neutron subnet-create --name ${SUBNET1} --ip-version 4 --gateway ${NETWORK_GATEWAY1} ${NET1_ID} ${FIXED_RANGE1} | awk '/ id /{print $4}')

echo ${NET_MGMT_ID}
echo ${SUBNET_MGMT_ID}
echo ${NET0_ID}
echo ${SUBNET0_ID}
echo ${NET1_ID}
echo ${SUBNET1_ID}

TEMPLATE_ID=$(neutron svcvm-device-template-create --template-service-type ${SERVICE_TYPE} --device-driver ${HOSTING_DEVICE_DRIVER} --mgmt-driver ${MGMT_DRIVER} --name ${NAME} --attribute flavorRef ${FLAVOR_ID} --attribute imageRef ${IMAGE_ID} --attribute mgmt-network ${NET_MGMT_ID} | awk '/ id /{print $4}')

LB_PROVIDER=HostingDevice
POOL0=pool0
PROTOCOL=HTTP

POOL0_ID=$(neutron lb-pool-create --lb-method ROUND_ROBIN --name ${POOL0} --protocol ${PROTOCOL} --subnet-id ${SUBNET0_ID} --provider ${LB_PROVIDER} | awk '/ id /{print $4}')
echo ${POOL0_ID}
neutron lb-pool-list
neutron lb-pool-show ${POOL0_ID}
neutron lb-pool-delete ${POOL0_ID}
POOL0_ID=$(neutron lb-pool-create --lb-method ROUND_ROBIN --name ${POOL0} --protocol ${PROTOCOL} --subnet-id ${SUBNET0_ID} --provider ${LB_PROVIDER} | awk '/ id /{print $4}')

# don't create member for now
# SERVER1_IP=xxxx
# neutron lb-member-create --address ${SERVER1_IP} --protocol-port 80 mypool

# don't create health monitor for now
# neutron lb-healthmonitor-create --delay 3 --type HTTP --max-retries 3 --timeout 3
# neutron lb-healthmonitor-associate <healthmonitor-uuid> mypool


VIP=myvip
VIP_PORT=80
VIP_ID=$(neutron lb-vip-create --name ${VIP} --protocol-port ${VIP_PORT} --protocol ${PROTOCOL} --subnet-id ${SUBNET1_ID} ${POOL0_ID} | awk '/ id /{print $4}')
PORT_ID=$(neutron lb-vip-show ${VIP_ID} | awk '/ port_id /{print $4})'
neutron lb-vip-delete ${VIP_ID}


HOSTING_DEVICE_ID=$(neutron svcvm-device-create --service-context network-id=${NET_MGMT_ID},subnet-id=${SUBNET_MGMT_ID},role=mgmt --service-context network-id=${NETWORK_ID1},subnet-id=${SUBNET1_ID},port-id=${PORT_ID},role=two-leg-ingress --service-context network-id=${NETWORK_ID0},subnet-id=${SUBNET0_ID},role=two-leg-egress --device-template-id ${TEMPLATE_ID} | awk '/ id /{print $4}')
neutron svcvm-device-list
neutron svcvm-device-show ${HOSTING_DEVICE_ID}
neutron svcvm-device-delete ${HOSTING_DEVICE_ID}

HOSTING_DEVICE_ID=$(neutron svcvm-device-create --service-context network-id=${NET_MGMT_ID},subnet-id=${SUBNET_MGMT_ID},role=mgmt --service-context network-id=${NETWORK_ID1},subnet-id=${SUBNET1_ID},port=${PORT_ID},role=two-leg-ingress --service-context network-id=${NETWORK_ID0},subnet-id=${SUBNET0_ID},role=two-leg-egress --device-template-id ${TEMPLATE_ID} | awk '/ id /{print $4}')

VIP_ID=$(neutron lb-vip-create --name ${VIP} --protocol-port ${VIP_PORT} --protocol ${PROTOCOL} --subnet-id ${SUBNET1_ID} ${POOL0_ID} | awk '/ id /{print $4}')
neutron lb-vip-delete ${VIP_ID}
neutron svcvm-device-delete ${HOSTING_DEVICE_ID}

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"


FLAVOR_ID=$(nova flavor-show m1.tiny  | awk '/ id /{print $4}')
IMAGE_ID=$(nova image-show ${IMAGE} | awk '/ id /{print $4}')

UUID=$(uuidgen)

NET_MGMT=net_mgmt_${UUID}
SUBNET_MGMT=subnet_mgmt_${UUID}
FIXED_RANGE_MGMT=10.253.255.0/24
NETWORK_GATEWAY_MGMT=10.253.255.1

NET0=net0_${UUID}
SUBNET0=subnet0_${UUID}
FIXED_RANGE0=10.253.0.0/24
NETWORK_GATEWAY0=10.253.0.1

NET1=net1_${UUID}
SUBNET1=subnet1_${UUID}
FIXED_RANGE1=10.253.1.0/24
NETWORK_GATEWAY1=10.253.1.1

NET_MGMT_ID=$(neutron net-create ${NET_MGMT} | awk '/ id /{print $4}')
SUBNET_MGMT_ID=$(neutron subnet-create --name ${SUBNET_MGMT} --ip-version 4 --gateway ${NETWORK_GATEWAY_MGMT} ${NET_MGMT_ID} ${FIXED_RANGE_MGMT} | awk '/ id /{print $4}')
NET0_ID=$(neutron net-create ${NET0} | awk '/ id /{print $4}')
SUBNET0_ID=$(neutron subnet-create --name ${SUBNET0} --ip-version 4 --gateway ${NETWORK_GATEWAY0} ${NET0_ID} ${FIXED_RANGE0} | awk '/ id /{print $4}')
NET1_ID=$(neutron net-create ${NET1} | awk '/ id /{print $4}')
SUBNET1_ID=$(neutron subnet-create --name ${SUBNET1} --ip-version 4 --gateway ${NETWORK_GATEWAY1} ${NET1_ID} ${FIXED_RANGE1} | awk '/ id /{print $4}')
TEMPLATE_ID=$(neutron svcvm-device-template-create --template-service-type ${SERVICE_TYPE} --device-driver ${HOSTING_DEVICE_DRIVER} --mgmt-driver ${MGMT_DRIVER} --name ${NAME} --attribute flavorRef ${FLAVOR_ID} --attribute imageRef ${IMAGE_ID} --attribute mgmt-network ${NET_MGMT_ID} | awk '/ id /{print $4}')
POOL0_ID=$(neutron lb-pool-create --lb-method ROUND_ROBIN --name ${POOL0} --protocol ${PROTOCOL} --subnet-id ${SUBNET0_ID} --provider ${LB_PROVIDER} | awk '/ id /{print $4}')
VIP_ID=$(neutron lb-vip-create --name ${VIP} --protocol-port ${VIP_PORT} --protocol ${PROTOCOL} --subnet-id ${SUBNET1_ID} ${POOL0_ID} | awk '/ id /{print $4}')
