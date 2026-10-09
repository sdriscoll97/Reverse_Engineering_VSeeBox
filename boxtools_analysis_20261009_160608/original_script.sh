#!/bin/bash
# BoxTools AIDL Service Analysis Script
# Focuses on analyzing the BoxTools service capabilities and potential vulnerabilities

set -euo pipefail

# Configuration
DEVICE_IP="10.42.0.130"
OUTPUT_DIR="${HOME}/firstproject/boxtools_analysis_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${OUTPUT_DIR}/boxtools_analysis.log"

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo "Starting BoxTools analysis..." | tee "$LOG_FILE"

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

log "=== BOXTOOLS AIDL SERVICE ANALYSIS ==="
log "Target Device: $DEVICE_IP"
log "Output Directory: $OUTPUT_DIR"

# Check BoxTools package details
log "Checking BoxTools package information..."
run_and_save "adb shell pm dump com.qstar.apps.boxtools" "boxtools_dump.txt" "BoxTools Package Dump"
run_and_save "adb shell dumpsys package com.qstar.apps.boxtools" "boxtools_dumpsys.txt" "BoxTools Dumpsys"

# Check service information
log "Checking BoxTools services..."
run_and_save "adb shell dumpsys activity services | grep -A 10 -B 5 boxtools" "boxtools_services.txt" "BoxTools Services Information"
run_and_save "adb shell service list | grep -i boxtools" "boxtools_service_list.txt" "BoxTools Service List"

# Check permissions and capabilities
log "Checking BoxTools permissions..."
run_and_save "adb shell pm list permissions | grep -i boxtools" "boxtools_permissions.txt" "BoxTools Permissions"
run_and_save "adb shell pm list permissions | grep -i system" "system_permissions.txt" "System Permissions"

# Check for AIDL interfaces
log "Checking for AIDL-related files..."
run_and_save "adb shell find /data -name '*aidl*' 2>/dev/null" "aidl_files.txt" "AIDL Files"
run_and_save "adb shell find /data/data/com.qstar.apps.boxtools -name '*' 2>/dev/null | head -20" "boxtools_data_files.txt" "BoxTools Data Files"

# Check system-level access
log "Checking system access points..."
run_and_save "adb shell ls -la /system/etc/ | grep -i boxtools" "boxtools_system_config.txt" "BoxTools System Config"
run_and_save "adb shell ls -la /data/system/ | grep -i boxtools" "boxtools_system_data.txt" "BoxTools System Data"

# Check for system-level commands that might be available
log "Checking for system utilities..."
run_and_save "adb shell which su" "which_su.txt" "Finding su binary"
run_and_save "adb shell which busybox" "which_busybox.txt" "Finding busybox"
run_and_save "adb shell which sh" "which_sh.txt" "Finding shell"

# Check for any debug features in BoxTools
log "Checking for debug features..."
run_and_save "adb shell ls -la /data/local/tmp/ | grep -i boxtools" "boxtools_tmp_files.txt" "BoxTools Temp Files"
run_and_save "adb shell getprop | grep -i boxtools" "boxtools_props.txt" "BoxTools Properties"

# Check the actual service implementation (if accessible)
log "Checking service implementation details..."
run_and_save "adb shell ls -la /data/data/com.qstar.apps.boxtools/files/" "boxtools_files.txt" "BoxTools Files"

# Summary of BoxTools capabilities
log "=== BOXTOOLS CAPABILITIES SUMMARY ==="
echo "Analysis Time: $(date)" >> "${OUTPUT_DIR}/summary.txt"
echo "BoxTools Package: com.qstar.apps.boxtools" >> "${OUTPUT_DIR}/summary.txt"
echo "System UID: $(adb shell dumpsys package com.qstar.apps.boxtools 2>/dev/null | grep -i uid | head -1 || echo 'Unknown')" >> "${OUTPUT_DIR}/summary.txt"
echo "Shared User ID: android.uid.system" >> "${OUTPUT_DIR}/summary.txt"
echo "Key Permissions: INSTALL_PACKAGES, DELETE_PACKAGES, WRITE_SECURE_SETTINGS" >> "${OUTPUT_DIR}/summary.txt"

# Save the script itself for future reference
cp "$0" "${OUTPUT_DIR}/original_script.sh"

log "BoxTools analysis complete. Output saved to: $OUTPUT_DIR"
log "Files created:"
ls -la "$OUTPUT_DIR" | grep -v "^\-" | awk '{print "  - " $NF}' | head -20

echo "BoxTools analysis complete. Files saved to: $OUTPUT_DIR"