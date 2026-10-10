# VSeeBox Root Setup Plan

## Current State (updated 2026-10-09)
- Device is reachable on the home network at `192.168.1.163` / `192.168.1.167` (MAC `b4:5b:d6:b1:8d:36`), over the same switch as the Optiplex (`192.168.1.168`). See `NETWORK_STATUS.md`.
- Device is debuggable (ro.debuggable=1)
- We have identified BoxTools AIDL service with system privileges
- ADB access not yet established: ADB-over-TCP ports 5555/5037 are closed; enable USB debugging on the device, then `adb connect 192.168.1.167:5555` (or connect over USB).

## Immediate Actions to Take

### 1. Diagnose USB Connection Issue
We've created `usb_diagnosis.py` to help identify why the USB connection isn't working:
- Check if device appears in lsusb
- Verify kernel USB messages
- Test ADB connectivity
- Confirm network configuration

### 2. Prepare for Root Access
We've created `root_prep.py` which:
- Documents the attack surface we've identified
- Outlines the key services and privileges
- Details the attack vectors we've mapped
- Prepares the framework for root access deployment

### 3. Next Steps When USB Is Available
Once we can physically connect the device:
1. Enable USB debugging on the device
2. Connect via ADB to establish shell access
3. Use BoxTools service to escalate privileges
4. Deploy root solution using system-level access

## Technical Approach

Based on our findings from `findings.md` and `root_access_strategy.md`:

### Attack Surface
- **BoxTools service** (`com.qstar.apps.boxtools`) with system privileges:
  - INSTALL_PACKAGES, DELETE_PACKAGES, WRITE_SECURE_SETTINGS, QUERY_ALL_PACKAGES
  - `AidlMessageService` - handles remote commands via AIDL
  - `SilentInstallService` - can install apps silently

### Root Access Methodology
1. **Network-based approach**: Since we can already reach the device, we can analyze its communication patterns and prepare exploits
2. **USB debugging approach**: When physical access is possible, we'll enable USB debugging and leverage the BoxTools service
3. **Privilege escalation**: Use the existing system privileges in BoxTools to gain root access

## Files Created
- `vseebox/scripts/usb_diagnosis.py` - For diagnosing USB connection issues
- `vseebox/scripts/root_prep.py` - For preparing root access framework
- `vseebox/root_access_preparation.md` - Detailed documentation of our approach

## Risk Assessment
Low risk factors:
- Device is designed for remote management
- Debug features are intended for development/testing
- No obvious security flaws in exposed interfaces

Moderate risk factors:
- BoxTools service has extensive system privileges
- Device communicates with external servers
- AIDL service may be vulnerable to command injection

## Recommendation
Continue monitoring the device's network behavior while we wait for physical access to enable USB debugging. All necessary preparation is complete for when the USB connection becomes available.