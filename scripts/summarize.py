#!/usr/bin/env python3
"""Summarize classic Ethernet PCAP without printing URLs, cookies or payloads.
Packet-local header hints only; no TCP reassembly or decryption.
"""
import argparse
from collections import Counter, defaultdict
import ipaddress
import json
import struct


def packets(stream):
    header = stream.read(24)
    magic = {b'\xd4\xc3\xb2\xa1': ('<', 1e6), b'\xa1\xb2\xc3\xd4': ('>', 1e6),
             b'\x4d\x3c\xb2\xa1': ('<', 1e9), b'\xa1\xb2\x3c\x4d': ('>', 1e9)}
    if len(header) != 24 or header[:4] not in magic:
        raise ValueError('Expected classic PCAP')
    endian, scale = magic[header[:4]]
    if struct.unpack(endian + 'I', header[20:24])[0] != 1:
        raise ValueError('Expected Ethernet link type')
    while True:
        record = stream.read(16)
        if not record:
            return
        if len(record) != 16:
            raise ValueError('Truncated record header')
        sec, fraction, captured, original = struct.unpack(endian + 'IIII', record)
        if captured > 16 * 1024 * 1024:
            raise ValueError('Oversized record')
        frame = stream.read(captured)
        if len(frame) != captured:
            raise ValueError('Truncated packet')
        yield sec + fraction / scale, original, frame


def summarize(stream, target):
    ipaddress.ip_address(target)
    flows = defaultdict(lambda: Counter())
    hints = Counter()
    count = size = skipped = 0
    first = last = None
    for timestamp, original, frame in packets(stream):
        count += 1
        size += original
        first = timestamp if first is None else min(first, timestamp)
        last = timestamp if last is None else max(last, timestamp)
        if len(frame) < 34 or frame[12:14] != b'\x08\x00':
            skipped += 1
            continue
        ip = frame[14:]
        ihl = (ip[0] & 15) * 4
        total = int.from_bytes(ip[2:4], 'big')
        if ip[0] >> 4 != 4 or ihl < 20 or len(ip) < total or total < ihl:
            skipped += 1
            continue
        src, dst = str(ipaddress.ip_address(ip[12:16])), str(ipaddress.ip_address(ip[16:20]))
        if target not in (src, dst) or int.from_bytes(ip[6:8], 'big') & 0x3fff:
            skipped += 1
            continue
        transport = ip[ihl:total]
        proto = ip[9]
        if proto not in (6, 17) or len(transport) < (20 if proto == 6 else 8):
            skipped += 1
            continue
        sport, dport = struct.unpack('!HH', transport[:4])
        outgoing = src == target
        remote, port = (dst, dport) if outgoing else (src, sport)
        key = (remote, port, 'TCP' if proto == 6 else 'UDP')
        flow = flows[key]
        flow['packets'] += 1
        flow['outbound_frame_bytes' if outgoing else 'inbound_frame_bytes'] += original
        offset = (transport[12] >> 4) * 4 if proto == 6 else 8
        if offset < (20 if proto == 6 else 8) or offset > len(transport):
            continue
        payload = transport[offset:]
        if payload.startswith(b'HTTP/'):
            hints['http_response_packet_prefix'] += 1
        for mime in (b'application/vnd.apple.mpegurl', b'application/x-mpegurl', b'application/dash+xml', b'video/mp2t', b'video/mp4', b'application/octet-stream'):
            # Match only complete header lines to avoid exporting arbitrary data.
            if b'content-type: ' + mime in payload[:4096].lower():
                hints[mime.decode()] += 1
        if payload.startswith(b'#EXTM3U'):
            hints['hls_playlist_packet_prefix'] += 1
        if len(payload) >= 377 and payload[0] == payload[188] == payload[376] == 0x47:
            hints['mpeg_ts_188_byte_sync_packet_prefix'] += 1
        if len(payload) >= 5 and payload[0] in (20, 21, 22, 23) and payload[1] == 3 and payload[2] <= 4:
            hints['possible_tls_record_packet_prefix'] += 1
    duration = last - first if first is not None else 0
    return {'packets': count, 'original_frame_bytes': size, 'duration_seconds': duration,
            'first_epoch': first, 'last_epoch': last, 'mean_frame_mbps': size * 8 / duration / 1e6 if duration else 0,
            'unclassified_packets': skipped, 'packet_local_hints': dict(hints),
            'flows': [dict(remote=k[0], remote_port=k[1], transport=k[2], **v)
                      for k, v in sorted(flows.items(), key=lambda item: sum(item[1][n] for n in ('inbound_frame_bytes','outbound_frame_bytes')), reverse=True)]}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pcap')
    parser.add_argument('--target', required=True)
    args = parser.parse_args()
    with open(args.pcap, 'rb') as stream:
        print(json.dumps(summarize(stream, args.target), indent=2))
