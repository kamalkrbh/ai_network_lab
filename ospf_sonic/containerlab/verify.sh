#!/bin/bash

LAB_NAME="ospf-ecmp-sonic-only"
NODES="r1 r2 r3 r4"

echo "🔍 Starting OSPF Verification..."

for node in $NODES; do
    echo "=== $node Neighbors ==="
    docker exec clab-$LAB_NAME-$node vtysh -c "show ip ospf neighbor"
done

echo "=== R1 Routing Table (4.4.4.4) ==="
docker exec clab-$LAB_NAME-r1 vtysh -c "show ip route 4.4.4.4" | grep via

echo "=== R4 Routing Table (1.1.1.1) ==="
docker exec clab-$LAB_NAME-r4 vtysh -c "show ip route 1.1.1.1" | grep via

echo "✅ Verification complete. Look for 'Full' neighbors and 2 'via' paths for ECMP."
