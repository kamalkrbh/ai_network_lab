#!/bin/bash

# Lab name from topology.clab.yml
LAB_NAME="ospf-ecmp-sonic-only"
NODES="r1 r2 r3 r4"

echo "🚀 Starting post-deploy setup for $LAB_NAME..."

for node in $NODES; do
    echo "------------------------------------------"
    echo "⚙️  Configuring $node..."
    
    # 1. Bring data-plane interfaces up
    echo "   -> Bringing eth1 up..."
    docker exec clab-$LAB_NAME-$node ip link set eth1 up
    
    echo "   -> Bringing eth2 up..."
    docker exec clab-$LAB_NAME-$node ip link set eth2 up
    
    if [[ "$node" == "r1" || "$node" == "r4" ]]; then
        echo "   -> Bringing eth3 up..."
        docker exec clab-$LAB_NAME-$node ip link set eth3 up
    fi
    
    # 2. Set MTU to 1500 (as required by prompt)
    echo "   -> Setting MTU 1500 on eth1/eth2..."
    docker exec clab-$LAB_NAME-$node ip link set dev eth1 mtu 1500
    docker exec clab-$LAB_NAME-$node ip link set dev eth2 mtu 1500
    
    # 3. Restart FRR to apply configs from /etc/frr/
    echo "   -> Restarting FRR service..."
    docker exec clab-$LAB_NAME-$node service frr restart
    
    echo "✅ $node setup complete."
done

echo "------------------------------------------"
echo "🏁 All nodes configured. Please wait for OSPF convergence."
