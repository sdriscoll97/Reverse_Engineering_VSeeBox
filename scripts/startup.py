#!/usr/bin/env python3
"""Packet-local startup timeline. Never emits URLs, headers, DNS values or payloads."""
import argparse
from collections import Counter, defaultdict
import datetime
import ipaddress
import json
from pathlib import Path
import re
import struct
from summarize import packets


def analyze(directory, target):
    metadata = json.loads((directory / 'metadata.json').read_text())
    start = datetime.datetime.fromisoformat(metadata['started_utc']).timestamp()
    bins = defaultdict(Counter)
    requests = Counter()
    responses = Counter()
    first = {}
    with (directory / 'traffic.pcap').open('rb') as stream:
        for timestamp, original, frame in packets(stream):
            relative = timestamp - start
            bucket = int(relative // 5) * 5
            bins[bucket]['frame_bytes'] += original
            bins[bucket]['packets'] += 1
            if len(frame) < 34 or frame[12:14] != b'\x08\x00':
                continue
            ip = frame[14:]
            ihl = (ip[0] & 15) * 4
            total = int.from_bytes(ip[2:4], 'big')
            if ip[0] >> 4 != 4 or ihl < 20 or total < ihl or len(ip) < total or int.from_bytes(ip[6:8], 'big') & 0x3fff:
                continue
            src, dst = str(ipaddress.ip_address(ip[12:16])), str(ipaddress.ip_address(ip[16:20]))
            if target not in (src, dst) or ip[9] != 6:
                continue
            tcp = ip[ihl:total]
            if len(tcp) < 20:
                continue
            offset = (tcp[12] >> 4) * 4
            if offset < 20 or offset > len(tcp):
                continue
            payload = tcp[offset:]
            direction = 'outbound' if src == target else 'inbound'
            bins[bucket][direction + '_tcp_payload_bytes'] += len(payload)
            if tcp[13] & 2 and not tcp[13] & 16:
                bins[bucket]['syn_without_ack_packets'] += 1
            request = re.match(rb'(GET|POST|HEAD|PUT|OPTIONS|CONNECT) ([^\r\n ]+) HTTP/1\.[01]\r\n', payload)
            if request:
                path = request[2].split(b'?', 1)[0].lower()
                suffix = next((ext for ext in (b'.m3u8', b'.mpd', b'.ts', b'.mp4', b'.m4s') if path.endswith(ext)), b'other')
                requests[request[1].decode() + ' ' + suffix.decode()] += 1
                first.setdefault('http_request_seconds', relative)
            response = re.match(rb'HTTP/1\.[01] ([0-9]{3}) ', payload)
            if response:
                responses[response[1].decode()] += 1
                first.setdefault('http_response_seconds', relative)
                if b'\r\n\r\n' in payload:
                    body = payload.split(b'\r\n\r\n', 1)[1]
                    if body.startswith(b'#EXTM3U'):
                        responses['body_hls_prefix'] += 1
                    if any(len(body) > i+376 and body[i] == body[i+188] == body[i+376] == 0x47 for i in range(min(188,len(body)))):
                        responses['body_three_mpeg_ts_sync_bytes'] += 1
    return {'bin_width_seconds': 5, 'times_relative_to_capture_metadata_start': True,
            'first_observed': first, 'http_request_packet_counts': dict(requests),
            'http_response_packet_counts': dict(responses),
            'bins': [dict(start_seconds=k, **v) for k,v in sorted(bins.items())],
            'limits': 'No TCP reassembly or retransmission deduplication. Packet-local signatures may miss split headers. Payload byte counts include retransmissions.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture_directory', type=Path)
    parser.add_argument('--target', required=True)
    args = parser.parse_args()
    ipaddress.ip_address(args.target)
    print(json.dumps(analyze(args.capture_directory, args.target), indent=2))
