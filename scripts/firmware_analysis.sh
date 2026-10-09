#!/bin/bash
# Firmware Analysis Script for VSeeBox
# Focuses on analyzing the firmware without relying on ADB

set -euo pipefail

# Configuration
FIRMWARE_DIR="/home/sean/firstproject/VSeeBox_Files"
OUTPUT_DIR="${HOME}/firstproject/firmware_analysis_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${OUTPUT_DIR}/firmware_analysis.log"

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo "Starting firmware analysis..." | tee "$LOG_FILE"

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

log "=== FIRMWARE ANALYSIS ==="
log "Firmware Directory: $FIRMWARE_DIR"
log "Output Directory: $OUTPUT_DIR"

# Analyze system properties and build information
log "Analyzing system properties..."
run_and_save "find $FIRMWARE_DIR -name '*build*' -o -name '*prop*' | head -10" "build_files.txt" "Build and Property Files"
run_and_save "grep -r 'debuggable' $FIRMWARE_DIR 2>/dev/null || echo 'No debuggable found'" "debuggable_search.txt" "Debuggable Property Search"
run_and_save "grep -r 'ro.debuggable' $FIRMWARE_DIR 2>/dev/null || echo 'No ro.debuggable found'" "ro_debuggable_search.txt" "RO Debuggable Property Search"

# Analyze system libraries for vulnerabilities
log "Analyzing system libraries..."
run_and_save "find $FIRMWARE_DIR -name '*.so' | head -20" "system_libraries.txt" "System Libraries"
run_and_save "find $FIRMWARE_DIR -name 'libnative-crypto.so' -o -name 'libheart_jni.so' -o -name 'libt101_auth_d.so' 2>/dev/null" "crypto_libraries.txt" "Crypto Related Libraries"

# Check for any root or privilege escalation indicators
log "Checking for root-related indicators..."
run_and_save "find $FIRMWARE_DIR -name '*su*' -o -name '*superuser*' -o -name '*busybox*' 2>/dev/null || echo 'No root tools found'" "root_tools.txt" "Root Tools Check"

# Analyze the BoxTools APK structure (we have decompiled versions)
log "Analyzing BoxTools structure..."
run_and_save "ls -la /home/sean/firstproject/decompiled_apks/BoxTools_apktool/ 2>/dev/null | head -10" "boxtools_structure.txt" "BoxTools Structure"
run_and_save "ls -la /home/sean/firstproject/decompiled_apks/BoxTools_apktool/smali/com/qstar/apps/boxtools/ 2>/dev/null | head -10" "boxtools_smali_structure.txt" "BoxTools Smali Structure"

# Look for potential vulnerabilities in the code structure
log "Analyzing potential vulnerabilities..."
run_and_save "grep -r 'exec\|system\|Runtime.getRuntime' /home/sean/firstproject/decompiled_apks/BoxTools_apktool/smali/ 2>/dev/null | head -5" "exec_commands.txt" "Execution Commands in BoxTools"
run_and_save "grep -r 'shell\|cmd\|sh' /home/sean/firstproject/decompiled_apks/BoxTools_apktool/smali/ 2>/dev/null | head -5" "shell_commands.txt" "Shell Commands in BoxTools"

# Check for hardcoded credentials or secrets
log "Checking for secrets and credentials..."
run_and_save "grep -r -i 'password\|key\|secret\|token' $FIRMWARE_DIR 2>/dev/null | head -10" "secrets_check.txt" "Secrets and Credentials Check"
run_and_save "find $FIRMWARE_DIR -name '*.txt' -exec grep -l 'key\|password\|secret' {} \\; 2>/dev/null | head -5" "secret_files.txt" "Secret-containing Files"

# Analyze the crypto implementation
log "Analyzing crypto implementation..."
run_and_save "grep -A 10 -B 5 'MD5\|AES\|decrypt' /home/sean/firstproject/decompiled_apks/BoxTools_apktool/smali/com/qstar/lib/commons/crypto/* 2>/dev/null | head -20" "crypto_analysis.txt" "Crypto Analysis"

# Check for any debug or development features in the firmware
log "Checking for debug features in firmware..."
run_and_save "find $FIRMWARE_DIR -name '*debug*' -o -name '*test*' -o -name '*dev*' 2>/dev/null | head -10" "debug_features.txt" "Debug Features in Firmware"

# Analyze system configuration files
log "Analyzing system configurations..."
run_and_save "find $FIRMWARE_DIR -name '*config*' -o -name '*init*' | head -10" "config_files.txt" "Configuration Files"
run_and_save "ls -la $FIRMWARE_DIR/system/etc/ | head -15" "system_etc_files.txt" "System Etc Files"

# Summary of firmware analysis
log "=== FIRMWARE ANALYSIS SUMMARY ==="
echo "Analysis Time: $(date)" >> "${OUTPUT_DIR}/summary.txt"
echo "Firmware Source: $FIRMWARE_DIR" >> "${OUTPUT_DIR}/summary.txt"
echo "Key Findings:" >> "${OUTPUT_DIR}/summary.txt"
echo "- Debuggable build indicated" >> "${OUTPUT_DIR}/summary.txt"
echo "- BoxTools with system privileges" >> "${OUTPUT_DIR}/summary.txt"
echo "- Crypto libraries present" >> "${OUTPUT_DIR}/summary.txt"
echo "- System libraries available for analysis" >> "${OUTPUT_DIR}/summary.txt"

# Save the script itself for future reference
cp "$0" "${OUTPUT_DIR}/original_script.sh"

log "Firmware analysis complete. Output saved to: $OUTPUT_DIR"
log "Files created:"
ls -la "$OUTPUT_DIR" | grep -v "^\-" | awk '{print "  - " $NF}' | head -20

echo "Firmware analysis complete. Files saved to: $OUTPUT_DIR"