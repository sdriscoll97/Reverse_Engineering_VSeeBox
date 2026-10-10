# VSeeBox Network Connectivity Solution Plan

> **SUPERSEDED — RESOLVED (2026-10-09).** Do not follow the reconfiguration steps in this document; they are obsolete.
> The VSeeBox is now on the home network, reachable from the Optiplex over the same switch:
> - Optiplex: `192.168.1.168/24` (`enp2s0`, DHCP, gateway `192.168.1.254`)
> - VSeeBox: `192.168.1.163` and `192.168.1.167` (MAC `b4:5b:d6:b1:8d:36`)
> See **[NETWORK_STATUS.md](NETWORK_STATUS.md)** for the authoritative current setup. The original plan below is retained for history.

## Problem Statement
The Optiplex is on network 192.168.1.0/24 while the VSeeBox was originally on 192.168.50.0/24. This network segmentation prevents direct communication between our systems.

## Root Cause Analysis
From our documentation:
- VSeeBox was originally at 192.168.50.130
- Optiplex was originally at 192.168.50.1
- Both devices should be on the same network segment to communicate directly

## Solutions Available

### Solution 1: Change Optiplex Network Configuration
Configure Optiplex to use 192.168.50.0/24 network:
- Set static IP to 192.168.50.100 (or another available address)
- Set subnet mask to 255.255.255.0
- Set gateway to 192.168.50.1 (if that's the router)

### Solution 2: Network Routing
Set up routing between 192.168.1.0/24 and 192.168.50.0/24 networks if they're on the same router.

### Solution 3: Bridge Networks
Use a network bridge to connect the two network segments.

## Recommended Approach

Given that we need to ping the device to establish communication, the most reliable solution is to:

1. **Configure Optiplex to use 192.168.50.0/24 network**
2. **Set IP to 192.168.50.100** (avoiding conflict with the VSeeBox at 192.168.50.130)
3. **Use the same subnet mask (255.255.255.0)**

## Implementation Steps

### Step 1: Check Current Network Setup
```bash
ip addr show enp2s0
ip route
```

### Step 2: Configure New Network (Manual Method)
Since we cannot use sudo interactively due to auto-mode restrictions, we need to:
1. Document the correct configuration
2. Provide instructions for manual network configuration
3. Test connectivity once configuration is applied

### Step 3: Validate Connectivity
Once configured:
```bash
ping 192.168.50.130
```

## Alternative Approach for Testing

If we cannot immediately change the network configuration:
1. Use a network scanner to identify the device
2. Look for network bridges or routers that might connect the networks
3. Consider using a different approach for communication (like Tailscale if available)

## Documentation of Current State

### Current Network Configuration:
- Interface: enp2s0
- IP Address: 192.168.1.168/24
- Gateway: 192.168.1.254

### Target Network Configuration:
- Interface: enp2s0
- IP Address: 192.168.50.100/24
- Gateway: 192.168.50.1 (assuming router is at 192.168.50.1)

## Next Steps for Implementation

1. **Document the network configuration change needed**
2. **Provide instructions for manual network reconfiguration**
3. **Prepare for testing once network is reconfigured**

## Network Configuration Instructions

To configure the Optiplex to join the VSeeBox network:

### Method 1: Using NetworkManager (if available)
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

## Expected Outcome

After implementing the network change:
1. The Optiplex should be able to ping the VSeeBox at 192.168.50.130
2. Both devices should be on the same network segment
3. We can then proceed with USB debugging and root access setup

## Risk Assessment

Low risk:
- Changing network configuration temporarily may interrupt some network connections
- Will not affect device functionality beyond network access
- Can be reverted if needed

## Preparation for Root Access

Once we can ping the VSeeBox:
1. Proceed with USB debugging enablement
2. Use BoxTools AIDL service for privilege escalation
3. Deploy root solution using system-level access