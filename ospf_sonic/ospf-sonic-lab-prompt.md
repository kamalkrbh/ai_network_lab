# OSPF-Only ECMP SONiC FRR Lab Topology

**Purpose:** Demonstrate OSPF-based Equal Cost Multi-Path (ECMP) routing in a pure SONiC/FRR environment (use sonic latest docker image).

**Target Audience:** Network engineers learning OSPF fundamentals, ECMP load-balancing, and containerlab-based network emulation.

---

## Lab Topology

```
                  R2 (SONiC/FRR)
                /              \
Host1 -- R1 (SONiC/FRR)      R4 (SONiC/FRR) -- Host2
                \              /
                  R3 (SONiC/FRR)
```

**Topology Type:** Diamond (4 routers, 2 hosts)
**Routing:** OSPFv2 only, Area 0.0.0.0 backbone
**Network Type:** Point-to-Point on all P2P links
**ECMP Capability:** 2-path equal-cost load-balancing (R1↔R4 via R2 OR R3)

---

## IP Address Plan

### Loopback Addresses (Router IDs)
```
R1: 1.1.1.1/32
R2: 2.2.2.2/32
R3: 3.3.3.3/32
R4: 4.4.4.4/32
```

### Point-to-Point Links (/31 subnets)
```
R1 ↔ R2: 10.12.1.0/31
  R1: 10.12.1.0
  R2: 10.12.1.1

R1 ↔ R3: 10.13.1.0/31
  R1: 10.13.1.0
  R3: 10.13.1.1

R2 ↔ R4: 10.24.1.0/31
  R2: 10.24.1.0
  R4: 10.24.1.1

R3 ↔ R4: 10.34.1.0/31
  R3: 10.34.1.0
  R4: 10.34.1.1
```

### Host Networks (/24 subnets)
```
Host1 ↔ R1: 192.168.1.0/24
  R1: 192.168.1.1
  Host1: 192.168.1.2

Host2 ↔ R4: 192.168.2.0/24
  R4: 192.168.2.1
  Host2: 192.168.2.2
```

---

## Node Roles & Interfaces

**All Routers:** SONiC with FRR

**R1 (Ingress):**
- Links: eth1→R2, eth2→R3, eth3→Host1
- Loopback: 1.1.1.1/32

**R2 (Transit):**
- Links: eth1→R1, eth2→R4
- Loopback: 2.2.2.2/32

**R3 (Transit):**
- Links: eth1→R1, eth2→R4
- Loopback: 3.3.3.3/32

**R4 (Egress):**
- Links: eth1→R2, eth2→R3, eth3→Host2
- Loopback: 4.4.4.4/32

**Hosts:** Linux containers used as traffic source/sink

---

## OSPF Configuration Requirements (Generic)

- **OSPFv2, Area 0.0.0.0** on all routers
- **Router ID** must match the loopback IP
- **Point-to-Point network type** on all P2P links
- **Passive interfaces** for loopbacks and host-facing links (eth3 on R1/R4)
- **Equal costs** on both paths between R1 and R4 to enable ECMP
- **Hello/Dead timers** at FRR defaults unless explicitly overridden

---


