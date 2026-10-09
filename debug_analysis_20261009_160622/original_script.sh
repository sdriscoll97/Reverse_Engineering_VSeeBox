#!/bin/bash
# Debug Features Analysis Script
# Focuses on identifying debug features that could lead to root access

set -euo pipefail

# Configuration
DEVICE_IP="10.42.0.130"
OUTPUT_DIR="${HOME}/firstproject/debug_analysis_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${OUTPUT_DIR}/debug_analysis.log"

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo "Starting debug features analysis..." | tee "$LOG_FILE"

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

log "=== DEBUG FEATURES ANALYSIS ==="
log "Target Device: $DEVICE_IP"
log "Output Directory: $OUTPUT_DIR"

# Analyze debug-related system properties
log "Analyzing debug system properties..."
run_and_save "adb shell getprop | grep debug" "debug_properties.txt" "Debug Properties"
run_and_save "adb shell getprop | grep ro.debuggable" "ro_debuggable.txt" "ro.debuggable Property"
run_and_save "adb shell getprop | grep ro.build.type" "build_type.txt" "Build Type"
run_and_save "adb shell getprop | grep ro.secure" "ro_secure.txt" "Security Properties"

# Check for debug-related services
log "Checking debug services..."
run_and_save "adb shell service list | grep -i debug" "debug_services.txt" "Debug Services"
run_and_save "adb shell service list | grep -i adb" "adb_services.txt" "ADB Services"

# Check debug directories and files
log "Checking debug directories..."
run_and_save "adb shell ls -la /dev/ | grep -i debug" "debug_devices.txt" "Debug Devices"
run_and_save "adb shell ls -la /sys/kernel/debug/" "sys_kernel_debug.txt" "Kernel Debug Directory"
run_and_save "adb shell ls -la /proc/sys/kernel/ | grep -i debug" "proc_kernel_debug.txt" "Kernel Debug Sysctl"

# Check for debug binaries
log "Checking for debug binaries..."
run_and_save "adb shell find /system -name '*debug*' -type f 2>/dev/null" "debug_binaries.txt" "Debug Binaries"
run_and_save "adb shell find /system -name '*adb*' -type f 2>/dev/null" "adb_binaries.txt" "ADB Binaries"
run_and_save "adb shell find /system -name 'gdb*' -type f 2>/dev/null" "gdb_binaries.txt" "GDB Binaries"

# Check for any running debug processes
log "Checking running debug processes..."
run_and_save "adb shell ps | grep -i debug" "running_debug_processes.txt" "Running Debug Processes"
run_and_save "adb shell ps | grep -i gdb" "running_gdb_processes.txt" "Running GDB Processes"

# Check system logs for debug information
log "Checking system logs..."
run_and_save "adb shell dmesg | tail -50" "dmesg.txt" "Kernel Messages (last 50 lines)"
run_and_save "adb shell logcat -d -b events | tail -30" "events_logcat.txt" "Events Logcat (last 30 lines)"
run_and_save "adb shell logcat -d -b radio | tail -30" "radio_logcat.txt" "Radio Logcat (last 30 lines)"

# Check for any debug interfaces
log "Checking for debug interfaces..."
run_and_save "adb shell netstat -tulnp | grep -i debug" "debug_ports.txt" "Debug Ports"
run_and_save "adb shell ss -tulnp | grep -i debug" "debug_ports_ss.txt" "Debug Ports (ss)"

# Check SELinux and security contexts
log "Checking security contexts..."
run_and_save "adb shell getenforce" "selinux_status.txt" "SELinux Status"
run_and_save "adb shell getprop security.perf_harden" "security_perf_harden.txt" "Security Performance Harden"

# Check for any debugging configuration files
log "Checking debug configuration files..."
run_and_save "adb shell find /etc -name '*debug*' 2>/dev/null" "debug_configs.txt" "Debug Configuration Files"
run_and_save "adb shell find /data -name '*debug*' 2>/dev/null" "debug_data_files.txt" "Debug Data Files"

# Analyze the specific debuggable property
log "Analyzing ro.debuggable implications..."
echo "=== ro.debuggable Analysis ===" >> "${OUTPUT_DIR}/ro_debuggable_analysis.txt"
echo "Value: $(adb shell getprop ro.debuggable 2>/dev/null || echo 'Not found')" >> "${OUTPUT_DIR}/ro_debuggable_analysis.txt"
echo "This indicates debug features are enabled in the build." >> "${OUTPUT_DIR}/ro_debuggable_analysis.txt"
echo "Potential implications:" >> "${OUTPUT_DIR}/ro_debuggable_analysis.txt"
echo "- Debug symbols may be present" >> "${OUTPUT_DIR}/ro_debuggable_analysis.txt"
echo "- Debug interfaces may be accessible" >> "${OUTPUT_DIR}/ro_debuggable_analysis.txt"
echo "- System-level debugging capabilities may exist" >> "${OUTPUT_DIR}/ro_debuggable_analysis.txt"

# Summary of debug features
log "=== DEBUG FEATURES SUMMARY ==="
echo "Analysis Time: $(date)" >> "${OUTPUT_DIR}/summary.txt"
echo "Debuggable Build: $(adb shell getprop ro.debuggable 2>/dev/null || echo 'Unknown')" >> "${OUTPUT_DIR}/summary.txt"
echo "Build Type: $(adb shell getprop ro.build.type 2>/dev/null || echo 'Unknown')" >> "${OUTPUT_DIR}/summary.txt"
echo "SELinux Status: $(adb shell getenforce 2>/dev/null || echo 'Unknown')" >> "${OUTPUT_DIR}/summary.txt"
echo "Key Debug Features Found: $(find "$OUTPUT_DIR" -name "*.txt" -exec grep -l "debug\|Debug" {} \; 2>/dev/null | wc -l)" >> "${OUTPUT_DIR}/summary.txt"

# Save the script itself for future reference
cp "$0" "${OUTPUT_DIR}/original_script.sh"

log "Debug features analysis complete. Output saved to: $OUTPUT_DIR"
log "Files created:"
ls -la "$OUTPUT_DIR" | grep -v "^\-" | awk '{print "  - " $NF}' | head -20

echo "Debug features analysis complete. Files saved to: $OUTPUT_DIR"