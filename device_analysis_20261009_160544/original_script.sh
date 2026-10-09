#!/bin/bash
# Device Diagnostic Script for VSeeBox
# This script gathers comprehensive information about the device state
# for future root access troubleshooting

set -euo pipefail

# Configuration
DEVICE_IP="10.42.0.130"
OUTPUT_DIR="${HOME}/firstproject/device_analysis_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${OUTPUT_DIR}/diagnostic.log"

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo "Starting device diagnostic analysis..." | tee "$LOG_FILE"

# Function to log output
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to run command and save output
run_and_save() {
    local cmd="$1"
    local filename="$2"
    local description="$3"

    log "Running: $cmd"
    echo "=== $description ===" >> "${OUTPUT_DIR}/${filename}"
    eval "$cmd" 2>&1 >> "${OUTPUT_DIR}/${filename}" || echo "Command failed: $cmd" >> "${OUTPUT_DIR}/${filename}"
    echo "" >> "${OUTPUT_DIR}/${filename}"
}

log "=== DEVICE DIAGNOSTIC ANALYSIS ==="
log "Target Device: $DEVICE_IP"
log "Output Directory: $OUTPUT_DIR"

# Basic connectivity tests
log "Testing connectivity..."
ping -c 3 "$DEVICE_IP" >> "$LOG_FILE" 2>&1 || log "Ping failed"
traceroute -n "$DEVICE_IP" >> "$LOG_FILE" 2>&1 || log "Traceroute failed"

# Network port scan (limited to key ports)
log "Scanning key ports..."
nmap -p 22,23,80,443,8080 -T3 "$DEVICE_IP" >> "$LOG_FILE" 2>&1 || log "Nmap scan failed"

# System information gathering
log "Gathering system information..."

# Check if we can access device via ADB (even if not rooted)
log "Checking ADB connectivity..."
adb devices >> "$LOG_FILE" 2>&1 || log "ADB not available"

# Collect system properties
run_and_save "adb shell getprop" "system_properties.txt" "System Properties"
run_and_save "adb shell getprop ro.build.fingerprint" "build_fingerprint.txt" "Build Fingerprint"
run_and_save "adb shell getprop ro.debuggable" "debuggable_status.txt" "Debuggable Status"
run_and_save "adb shell getprop ro.product.build.type" "build_type.txt" "Build Type"

# Check running processes
run_and_save "adb shell ps" "running_processes.txt" "Running Processes"

# Check system directories
run_and_save "adb shell ls -la /system/bin/" "system_binaries.txt" "System Binaries"
run_and_save "adb shell ls -la /system/xbin/" "system_xbinaries.txt" "System Extended Binaries"
run_and_save "adb shell ls -la /data/local/tmp/" "data_local_tmp.txt" "Local Temporary Directory"

# Check for root-related files
run_and_save "adb shell find /system -name 'su' 2>/dev/null" "find_su.txt" "Finding su binary"
run_and_save "adb shell find /system -name 'superuser' 2>/dev/null" "find_superuser.txt" "Finding superuser"
run_and_save "adb shell find /system -name 'busybox' 2>/dev/null" "find_busybox.txt" "Finding busybox"

# Check network configuration
run_and_save "adb shell ip addr show" "network_interfaces.txt" "Network Interfaces"
run_and_save "adb shell netstat -tulnp" "network_connections.txt" "Network Connections"

# Check installed packages (especially BoxTools)
run_and_save "adb shell pm list packages | grep boxtools" "boxtools_packages.txt" "BoxTools Packages"
run_and_save "adb shell pm list packages | grep heat" "heat_packages.txt" "Heat Packages"

# Check services and daemons
run_and_save "adb shell service list" "services_list.txt" "Services List"

# Check log files for clues
run_and_save "adb shell logcat -d -b system | tail -50" "system_logcat.txt" "System Logcat (last 50 lines)"

# Check for debug features
run_and_save "adb shell ls -la /dev/ | grep debug" "debug_devices.txt" "Debug Devices"
run_and_save "adb shell ls -la /sys/kernel/debug/" "sys_kernel_debug.txt" "Kernel Debug Directory"

# Check for any running debug services
run_and_save "adb shell ps | grep debug" "debug_processes.txt" "Debug Processes"

# Check permissions and capabilities
run_and_save "adb shell ls -la /data/data/com.qstar.apps.boxtools/" "boxtools_data.txt" "BoxTools Data Directory"

# Check for any network-based debug features
run_and_save "adb shell cat /proc/net/sockstat" "socket_stats.txt" "Socket Statistics"

# Summary of findings
log "=== SUMMARY OF FINDINGS ==="
echo "Device IP: $DEVICE_IP" >> "${OUTPUT_DIR}/summary.txt"
echo "Analysis Time: $(date)" >> "${OUTPUT_DIR}/summary.txt"
echo "System Build: $(adb shell getprop ro.build.fingerprint 2>/dev/null || echo 'Unknown')" >> "${OUTPUT_DIR}/summary.txt"
echo "Debuggable: $(adb shell getprop ro.debuggable 2>/dev/null || echo 'Unknown')" >> "${OUTPUT_DIR}/summary.txt"
echo "BoxTools Installed: $(adb shell pm list packages | grep boxtools 2>/dev/null | wc -l)" >> "${OUTPUT_DIR}/summary.txt"

# Save the script itself for future reference
cp "$0" "${OUTPUT_DIR}/original_script.sh"

log "Diagnostic analysis complete. Output saved to: $OUTPUT_DIR"
log "Files created:"
ls -la "$OUTPUT_DIR" | grep -v "^\-" | awk '{print "  - " $NF}' | head -20

echo "Diagnostic analysis complete. Files saved to: $OUTPUT_DIR"