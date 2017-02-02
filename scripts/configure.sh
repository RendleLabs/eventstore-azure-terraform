#!/bin/bash

# This script is called with the IP address of "this" machine first, then the IP addresses of all machines
# in the cluster, including this machine's IP address again, because that's easiest from Terraform.
MY_IP=$1
shift

# So here, we skip this machine's IP address when building the GOSSIP_SEED value
GOSSIP_SEED=""
for arg; do
  if [ $arg != $MY_IP ] ; then
    GOSSIP_SEED="${GOSSIP_SEED},${arg}:2113"
  fi
done

# Strip leading comma
GOSSIP_SEED=${GOSSIP_SEED:1}

# This will become the configuration, overwriting anything already there.
# So this is where you should put your own configuration, between the !!!s

cat <<!!! >/etc/eventstore/eventstore.conf
---
RunProjections: All
ClusterSize: 3

IntIp: ${MY_IP}
ExtIp: ${MY_IP}

IntTcpPort: 1111
ExtTcpPort: 1112

IntHttpPort: 2113
IntHttpPrefixes: http://*:2113/

ExtHttpPort: 2114
ExtHttpPrefixes: http://*:2114/

AddInterfacePrefixes: false

DiscoverViaDns: false
GossipSeed: ${GOSSIP_SEED}
!!!

# Start EventStore
systemctl start eventstore