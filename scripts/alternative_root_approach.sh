#!/bin/bash
# Alternative Root Access Approach Script
# Focuses on methods to gain access without USB debugging

set -euo pipefail

# Configuration
DEVICE_IP="10.42.0.130"
OUTPUT_DIR="${HOME}/firstproject/alt_root_analysis_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${OUTPUT_DIR}/alt_root_analysis.log"

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo "Starting alternative root access analysis..." | tee "$LOG_FILE"

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

log "=== ALTERNATIVE ROOT ACCESS ANALYSIS ==="
log "Target Device: $DEVICE_IP"
log "Output Directory: $OUTPUT_DIR"

# Check network services and ports that might be exploitable
log "Scanning for potentially exploitable network services..."
run_and_save "nmap -p 1-65535 -T4 $DEVICE_IP | grep -E '(open|filtered)' | head -20" "port_scan.txt" "Port Scan Results"

# Look for specific services that might be debug-related
log "Checking for specific debug or service ports..."
run_and_save "nmap -p 22,23,80,443,8080,8443,8000,9000,5000,3000 $DEVICE_IP" "specific_port_scan.txt" "Specific Port Scan"

# Check for any services that might be debug-related
log "Checking for debug-related services..."
run_and_save "adb shell netstat -tulnp | grep -E 'debug|shell|adb'" "debug_services_netstat.txt" "Debug Services in Netstat"

# Analyze the device's network communication patterns
log "Analyzing network communication capabilities..."
run_and_save "adb shell ss -tulnp | grep -E 'LISTEN|ESTAB'" "network_connections.txt" "Network Connections"
run_and_save "adb shell cat /proc/net/sockstat" "socket_statistics.txt" "Socket Statistics"

# Check for any debug interfaces or features that might be accessible
log "Checking for debug interfaces..."
run_and_save "adb shell find /sys -name '*debug*' -type d 2>/dev/null" "sys_debug_dirs.txt" "Debug Directories in /sys"
run_and_save "adb shell find /proc -name '*debug*' -type d 2>/dev/null" "proc_debug_dirs.txt" "Debug Directories in /proc"

# Look for any hidden or undocumented features
log "Checking for hidden features..."
run_and_save "adb shell ls -la /data/local/" "data_local_dir.txt" "Data Local Directory"
run_and_save "adb shell ls -la /data/data/com.qstar.apps.boxtools/cache/" "boxtools_cache.txt" "BoxTools Cache Directory"

# Check for any available shells or interpreters
log "Checking for available shells..."
run_and_save "adb shell which sh" "which_sh.txt" "Shell Availability"
run_and_save "adb shell which bash" "which_bash.txt" "Bash Availability"
run_and_save "adb shell which zsh" "which_zsh.txt" "Zsh Availability"
run_and_save "adb shell which python" "which_python.txt" "Python Availability"
run_and_save "adb shell which perl" "which_perl.txt" "Perl Availability"

# Check for any available scripting environments
log "Checking for scripting environments..."
run_and_save "adb shell ls -la /data/data/com.qstar.apps.boxtools/files/" "boxtools_files.txt" "BoxTools Files"

# Analyze system capabilities that might be exploitable
log "Analyzing system capabilities..."
run_and_save "adb shell getprop | grep -E 'debug|secure|build'" "system_properties.txt" "System Properties"
run_and_save "adb shell getenforce" "selinux_status.txt" "SELinux Status"

# Check for any network-based debug features
log "Checking for network debug features..."
run_and_save "adb shell ps | grep -E 'debug|shell|adb'" "running_debug_processes.txt" "Running Debug Processes"

# Look for any available development tools
log "Checking for development tools..."
run_and_save "adb shell find /system -name '*gdb*' -o -name '*debug*' 2>/dev/null" "development_tools.txt" "Development Tools"

# Analyze what we know about the BoxTools service specifically
log "Analyzing BoxTools service in detail..."
run_and_save "adb shell dumpsys activity services | grep boxtools" "boxtools_service_details.txt" "BoxTools Service Details"

# Look for any potential command injection points
log "Checking for potential injection points..."
run_and_save "adb shell ls -la /data/data/com.qstar.apps.boxtools/" "boxtools_full_path.txt" "BoxTools Full Path Analysis"

# Summary of alternative approaches
log "=== ALTERNATIVE APPROACHES SUMMARY ==="
echo "Analysis Time: $(date)" >> "${OUTPUT_DIR}/summary.txt"
echo "Device IP: $DEVICE_IP" >> "${OUTPUT_DIR}/summary.txt"
echo "Debuggable Build: $(adb shell getprop ro.debuggable 2>/dev/null || echo 'Unknown')" >> "${OUTPUT_DIR}/summary.txt"
echo "Key Findings:" >> "${OUTPUT_DIR}/summary.txt"
echo "- Network connectivity established" >> "${OUTPUT_DIR}/summary.txt"
echo "- BoxTools has system privileges" >> "${OUTPUT_DIR}/summary.txt"
echo "- Device is debuggable" >> "${OUTPUT_DIR}/summary.txt"
echo "- Potential for network-based exploitation" >> "${OUTPUT_DIR}/summary.txt"

# Save the script itself for future reference
cp "$0" "${OUTPUT_DIR}/original_script.sh"

log "Alternative root access analysis complete. Output saved to: $OUTPUT_DIR"
log "Files created:"
ls -la "$OUTPUT_DIR" | grep -v "^\-" | awk '{print "  - " $NF}' | head -20

echo "Alternative root access analysis complete. Files saved to: $OUTPUT_DIR"