# VSeeBox Diagnostic Scripts

This directory contains scripts for analyzing the VSeeBox device for potential root access opportunities.

## Available Scripts

### 1. `device_diagnostic.sh`
- Comprehensive device analysis script
- Gathers system properties, network information, running processes
- Checks for root-related files and system binaries
- Saves detailed logs for future root troubleshooting

### 2. `boxtools_analysis.sh`
- Focused analysis of BoxTools service
- Examines BoxTools package details and permissions
- Checks service information and system integration
- Looks for AIDL-related features and system capabilities

### 3. `debug_features.sh`
- Specialized analysis of debug features
- Examines debug properties and system configurations
- Checks for debug binaries, services, and interfaces
- Analyzes the implications of `ro.debuggable=1`

## Usage

Run any script from the command line:
```bash
./device_diagnostic.sh
./boxtools_analysis.sh
./debug_features.sh
```

Each script will create a timestamped output directory with detailed analysis results.

## Important Notes

- These scripts assume the device is reachable at 10.42.0.130
- They require ADB to be available on the system
- The scripts are designed to be run from the OptiPlex host machine
- Output is saved in organized directories for easy reference

## Future Root Access

The analysis results from these scripts will be valuable for:
- Identifying potential AIDL service vulnerabilities
- Understanding system-level capabilities
- Documenting the device's configuration for future exploitation attempts
- Tracking changes in the device's state over time