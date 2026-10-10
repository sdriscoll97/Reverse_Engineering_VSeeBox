# Complete Solution: VSeeBox Network Connectivity and Root Setup

> **SUPERSEDED — RESOLVED (2026-10-09).** Do not follow the reconfiguration steps in this document; they are obsolete.
> The VSeeBox is now on the home network, reachable from the Optiplex over the same switch:
> - Optiplex: `192.168.1.168/24` (`enp2s0`, DHCP, gateway `192.168.1.254`)
> - VSeeBox: `192.168.1.163` and `192.168.1.167` (MAC `b4:5b:d6:b1:8d:36`)
> See **[NETWORK_STATUS.md](NETWORK_STATUS.md)** for the authoritative current setup. The original analysis below is retained for history.

## Problem Summary
Our Optiplex is on network 192.168.1.0/24 while the VSeeBox device was originally configured on 192.168.50.0/24. This network segmentation prevents us from directly communicating with the VSeeBox device, which is required for both:
1. Network-based analysis
2. USB debugging and root access

## Root Cause
From our documentation, the VSeeBox was at IP 192.168.50.130, but our Optiplex is at 192.168.1.168. The devices are on different network segments and cannot communicate directly.

## Solution Approach

### Step 1: Network Configuration Change
We need to configure our Optiplex to be on the same network segment as the VSeeBox:

**Target Configuration:**
- IP Address: 192.168.50.100 (avoiding conflict with VSeeBox at 192.168.50.130)
- Subnet Mask: 255.255.255.0 (/24)
- Gateway: 192.168.50.1 (assuming router is at this address)

### Step 2: Verification Process
Once network configuration is updated, we need to verify connectivity:
1. Ping the VSeeBox device
2. Confirm network reachability
3. Proceed with USB debugging setup

## Implementation Instructions

### Method 1: Using NetworkManager (Recommended)
```bash
# Set static IP configuration for enp2s0
nmcli con mod enp2s0 ipv4.addresses 192.168.50.100/24
nmcli con mod enp2s0 ipv4.gateway 192.168.50.1
nmcli con mod enp2s0 ipv4.method manual
nmcli con up enp2s0
```

### Method 2: Using ip command (requires sudo)
```bash
# Remove current IP
sudo ip addr del 192.168.1.168/24 dev enp2s0

# Add new IP
sudo ip addr add 192.168.50.100/24 dev enp2s0

# Bring interface up (should already be up)
sudo ip link set enp2s0 up
```

## Alternative Diagnostic Approach
Since we cannot directly make network changes due to auto-mode restrictions, we can:

1. **Document the exact network configuration needed**
2. **Test connectivity with our ping script once network is configured**
3. **Prepare all root access materials for immediate deployment**

## Network Troubleshooting Commands
Once network is configured, use these to verify connectivity:

```bash
# Check current network configuration
ip addr show enp2s0

# Test connectivity to VSeeBox
ping -c 3 192.168.50.130

# Show routing table
ip route

# Check ARP table for device
arp -a | grep 192.168.50.130
```

## Root Access Preparation
While resolving network connectivity, we've already prepared:

### Attack Surface Documentation
- BoxTools service (`com.qstar.apps.boxtools`) with system privileges:
  - INSTALL_PACKAGES, DELETE_PACKAGES, WRITE_SECURE_SETTINGS, QUERY_ALL_PACKAGES
  - `AidlMessageService` - handles remote commands via AIDL
  - `SilentInstallService` - can install apps silently

### Root Access Strategy
1. **USB Connection**: Enable USB debugging on device
2. **ADB Access**: Connect via ADB to establish shell access
3. **Privilege Escalation**: Use BoxTools system privileges to escalate access
4. **Root Deployment**: Deploy root solution using system-level access

## Next Steps
1. **Configure Optiplex network** to 192.168.50.0/24
2. **Verify connectivity** with ping test
3. **Establish USB debugging** when device is reachable
4. **Deploy root access** using BoxTools service

## Risk Assessment
**Low Risk Factors:**
- Changing network configuration temporarily may interrupt some connections
- Will not affect device functionality beyond network access
- Can be reverted if needed

**Moderate Risk Factors:**
- If network configuration is incorrect, may lose network access
- Requires careful attention to avoid IP conflicts

## Emergency Recovery
If network configuration causes issues:
```bash
# Restore original configuration
nmcli con mod enp2s0 ipv4.method auto
nmcli con up enp2s0
```

## Prepared Materials
All necessary materials for root access are already created:
- `vseebox/scripts/usb_diagnosis.py` - For USB connection diagnostics
- `vseebox/scripts/root_prep.py` - For root access framework preparation
- `vseebox/root_setup_plan.md` - Comprehensive root setup plan
- `vseebox/network_solution_plan.md` - Detailed network solution documentation