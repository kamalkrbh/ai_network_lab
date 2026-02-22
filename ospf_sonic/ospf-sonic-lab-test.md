# OSPF SONiC Lab - Essential Verification Guide

**Purpose:** Minimal, high-signal checks to validate OSPF adjacency, LSDB sync, and ECMP.

**Duration:** ~10 minutes

---

## Pre-Check (Quick)

- [ ] Lab deployed and containers running: `clab inspect`
- [ ] FRR daemons started on all routers
- [ ] OSPF configuration applied on all routers
- [ ] OSPF interfaces (eth1/eth2) are administratively up
- [ ] MTU is 1500 on all OSPF P2P links

---

## Step 1: Interfaces & MTU

### 1.1 Verify OSPF Links Are Up

```bash
for n in r1 r2 r3 r4; do
  echo "=== $n Links ===";
  docker exec clab-ospf-ecmp-sonic-only-$n ip -br link show dev eth1;
  docker exec clab-ospf-ecmp-sonic-only-$n ip -br link show dev eth2;
done
```

**Verify:** All OSPF P2P links show `UP` and `LOWER_UP`.

### 1.2 Verify MTU Consistency

```bash
for n in r1 r2 r3 r4; do
  echo "=== $n MTU ===";
  docker exec clab-ospf-ecmp-sonic-only-$n ip link show dev eth1 | grep mtu;
  docker exec clab-ospf-ecmp-sonic-only-$n ip link show dev eth2 | grep mtu;
done
```

**Verify:** MTU is **1500** on eth1/eth2 for all routers.

---

## Step 2: OSPF Neighbor Convergence

```bash
echo "⏳ Waiting 15 seconds for OSPF convergence..." && sleep 15
for n in r1 r2 r3 r4; do
  echo "=== $n Neighbors ===";
  docker exec clab-ospf-ecmp-sonic-only-$n vtysh -c "show ip ospf neighbor";
done
```

**Verify:**
- Each router has **2 neighbors** in **Full/-** state.

---

## Step 3: OSPF Database Synchronization

```bash
for n in r1 r2 r3 r4; do
  echo "=== $n LSDB ===";
  docker exec clab-ospf-ecmp-sonic-only-$n vtysh -c "show ip ospf database" | \
    awk '/Router Link States/{show=1;next} /Net Link States|Summary Link States|ASBR-Summary Link States|AS External Link States|NSSA External Link States/{show=0} show' | \
    grep -E '^[0-9]';
done
```

**Verify:** Each router lists **4 Router LSAs** (1.1.1.1, 2.2.2.2, 3.3.3.3, 4.4.4.4).

---

## Step 4: ECMP Route Verification

### 4.1 Check Full Routing Table (R1)

```bash
docker exec clab-ospf-ecmp-sonic-only-r1 vtysh -c "show ip route"
```

### 4.2 Verify Specific ECMP Routes

```bash
echo "=== R1 ECMP to R4 ===";
docker exec clab-ospf-ecmp-sonic-only-r1 vtysh -c "show ip route 4.4.4.4" | grep via;

echo "=== R4 ECMP to R1 ===";
docker exec clab-ospf-ecmp-sonic-only-r4 vtysh -c "show ip route 1.1.1.1" | grep via;
```

**Verify:** Each route shows **2 next-hops** with equal cost.

---

## Step 5: Load Balancing & Convergence Test

### 5.1 Verify ECMP Hashing (Host1 to Host2)
Verify that different flows take different paths by changing the source port.

```bash
echo "=== Flow 1 (Port 1001) ==="
docker exec clab-ospf-ecmp-sonic-only-host1 traceroute -n -p 1001 192.168.2.2
echo "=== Flow 2 (Port 2002) ==="
docker exec clab-ospf-ecmp-sonic-only-host1 traceroute -n -p 2002 192.168.2.2
```

**Verify:** At least one flow should show a different 2nd hop (10.12.1.1 vs 10.13.1.1).

**⚠️ Limitation (Virtual Lab):** In virtual environments like `sonic-vs`, the hashing algorithm can be extremely "sticky." You may find that many different ports still result in the same path. This is often due to the virtual kernel's hash policy being limited to Layer 3 (IPs) or having a biased hash seed. If multiple ports show the same path, proceed to **Step 5.2** to definitively verify both paths are active via link failure.

### 5.2 Link Failure & Path Redundancy (Enhanced)
Verify that traffic fails when all paths are down and recovers when *either* path is restored.

```bash
# 1. Start continuous ping from Host1 to Host2
echo "--- Starting reachability test ---"
docker exec clab-ospf-ecmp-sonic-only-host1 ping -c 3 192.168.2.2

# 2. ISOLATION: Shutdown BOTH eth1 and eth2 on R1
echo "--- Shutting down BOTH paths (eth1 & eth2) on R1 ---"
docker exec clab-ospf-ecmp-sonic-only-r1 ip link set eth1 down
docker exec clab-ospf-ecmp-sonic-only-r1 ip link set eth2 down
echo "⏳ Waiting for OSPF to detect failure..." && sleep 5

# 3. VERIFY FAILURE: Ping should now fail
echo "--- Verifying traffic fails (should see 100% loss) ---"
docker exec clab-ospf-ecmp-sonic-only-host1 ping -c 3 -W 1 192.168.2.2 || echo "✅ Traffic successfully blocked"

# 4. RESTORE PATH A: Bring up eth1 only
echo "--- Restoring Path A (eth1) ---"
docker exec clab-ospf-ecmp-sonic-only-r1 ip link set eth1 up
echo "⏳ Waiting for OSPF adjacency..." && sleep 15
docker exec clab-ospf-ecmp-sonic-only-host1 ping -c 3 192.168.2.2 && echo "✅ Path A is functional"

# 5. SWAP TO PATH B: Shut eth1, bring up eth2
echo "--- Swapping to Path B (eth1 DOWN, eth2 UP) ---"
docker exec clab-ospf-ecmp-sonic-only-r1 ip link set eth1 down
docker exec clab-ospf-ecmp-sonic-only-r1 ip link set eth2 up
echo "⏳ Waiting for OSPF adjacency..." && sleep 15
docker exec clab-ospf-ecmp-sonic-only-host1 ping -c 3 192.168.2.2 && echo "✅ Path B is functional"

# 6. FULL RESTORATION: Bring both up
echo "--- Restoring all paths ---"
docker exec clab-ospf-ecmp-sonic-only-r1 ip link set eth1 up
```

**Verify:** 
- Traffic fails completely when both interfaces are down.
- Traffic recovers when *only* `eth1` is up.
- Traffic recovers when *only* `eth2` is up.
- This confirms that both next-hops in the ECMP group are valid and capable of carrying traffic.

---

## Success Criteria

- All OSPF P2P interfaces are `UP/LOWER_UP` with MTU 1500
- All routers show 2 neighbors in Full/- state
- LSDB on every router contains 4 Router LSAs
- ECMP routes show 2 equal-cost paths in both directions

---
