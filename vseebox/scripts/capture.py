#!/usr/bin/env python3
"""Bounded, device-filtered capture; run locally with capture privileges."""
import argparse
import datetime
import ipaddress
import json
import os
from pathlib import Path
import subprocess


def command(interface, target, seconds, output):
    ipaddress.ip_address(target)
    if not interface or interface.startswith('-'):
        raise ValueError('Invalid interface')
    if not 1 <= seconds <= 600:
        raise ValueError('Duration must be 1–600 seconds')
    return ['timeout', '--signal=INT', str(seconds), 'tcpdump', '-i', interface,
            '-nn', '-s', '0', '-U', '-w', str(output), 'host', target]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--interface', required=True)
    parser.add_argument('--target', required=True)
    parser.add_argument('--seconds', type=int, default=60)
    parser.add_argument('--label', required=True, help='Observed playback state; omit credentials')
    parser.add_argument('--output-dir', type=Path, default=Path(__file__).resolve().parents[1] / 'private-captures')
    args = parser.parse_args()
    command(args.interface, args.target, args.seconds, Path('validate.pcap'))
    os.umask(0o077)
    started = datetime.datetime.now(datetime.timezone.utc)
    directory = args.output_dir / started.strftime('%Y%m%dT%H%M%S.%fZ')
    directory.mkdir(parents=True, exist_ok=False, mode=0o700)
    output = directory / 'traffic.pcap'
    cmd = command(args.interface, args.target, args.seconds, output)
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    metadata = {'started_utc': started.isoformat(), 'interface': args.interface,
                'target': args.target, 'requested_seconds': args.seconds, 'label': args.label,
                'command': cmd, 'exit_code': result.returncode, 'stderr': result.stderr,
                'capture_exists': output.exists(),
                'capture_bytes': output.stat().st_size if output.exists() else 0}
    (directory / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(directory)
    # timeout returns 124 after the requested duration, even when tcpdump exits cleanly.
    if result.returncode not in (0, 124) or metadata['capture_bytes'] <= 24:
        raise SystemExit('Capture failed or contains no packets; inspect metadata.json')


if __name__ == '__main__':
    main()
