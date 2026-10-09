#!/usr/bin/env python3
"""Compare two local summaries using the requested capture window for rates."""
import argparse
import json
from pathlib import Path


def load_capture(directory):
    metadata = json.loads((directory / 'metadata.json').read_text())
    summary = json.loads((directory / 'summary.json').read_text())
    seconds = metadata['requested_seconds']
    if seconds <= 0:
        raise ValueError('Capture duration must be positive')
    flows = summary['flows']
    metrics = {
        'requested_seconds': seconds,
        'packet_timestamp_span_seconds': summary['duration_seconds'],
        'packets': summary['packets'],
        'frame_bytes': summary['original_frame_bytes'],
        'frame_mbps_over_requested_window': summary['original_frame_bytes'] * 8 / seconds / 1e6,
        'remote_ips': len({f['remote'] for f in flows}),
        'endpoint_groups': len(flows),
        'groups_over_1MB': sum(f.get('inbound_frame_bytes', 0) + f.get('outbound_frame_bytes', 0) > 1000000 for f in flows),
    }
    for direction in ('inbound', 'outbound'):
        size = sum(f.get(direction + '_frame_bytes', 0) for f in flows)
        metrics[direction + '_frame_bytes'] = size
        metrics[direction + '_mbps_over_requested_window'] = size * 8 / seconds / 1e6
    return metrics, flows


def compare(playback, idle):
    active, active_flows = load_capture(playback)
    baseline, idle_flows = load_capture(idle)
    def key(f):
        return f['remote'], f['remote_port'], f['transport']
    idle_keys = {key(f) for f in idle_flows}
    heavy = [f for f in active_flows if f.get('inbound_frame_bytes', 0) + f.get('outbound_frame_bytes', 0) > 1000000]
    rate = active['frame_mbps_over_requested_window']
    idle_rate = baseline['frame_mbps_over_requested_window']
    return {'playback': active, 'idle': baseline,
            'frame_rate_reduction_percent': (1 - idle_rate / rate) * 100 if rate else None,
            'shared_remote_ips': len({f['remote'] for f in active_flows} & {f['remote'] for f in idle_flows}),
            'playback_heavy_groups_seen_in_idle': sum(key(f) in idle_keys for f in heavy),
            'rate_caveat': 'Requested windows; verify both captures completed. Frame rates include headers and retransmissions.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('playback', type=Path)
    parser.add_argument('idle', type=Path)
    args = parser.parse_args()
    print(json.dumps(compare(args.playback, args.idle), indent=2))
