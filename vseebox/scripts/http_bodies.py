#!/usr/bin/env python3
"""Bounded offline TCP/HTTP inspection. Exports counts and format hints only."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import struct
from summarize import packets

LIMIT = 32 * 1024 * 1024


def merge(segments):
    """Return contiguous runs, preserving gaps and counting conflicting overlaps."""
    if not segments:
        return [], 0
    base = segments[0][0]
    ordered = sorted((((seq-base+2**31) % 2**32)-2**31, data) for seq,data in segments)
    runs = []
    start = None
    data = bytearray()
    conflicts = 0
    for offset, payload in ordered:
        if start is None or offset > start + len(data):
            if start is not None:
                runs.append(bytes(data))
            start, data = offset, bytearray(payload)
            continue
        overlap = min(len(payload), start + len(data) - offset)
        position = offset-start
        conflicts += sum(a != b for a,b in zip(data[position:position+overlap],payload[:overlap]))
        data.extend(payload[overlap:])
    if start is not None:
        runs.append(bytes(data))
    return runs, conflicts


def body_hint(body):
    if body.startswith(b'#EXTM3U'):
        return 'HLS-like text'
    if body.startswith(b'FLV'):
        return 'FLV signature'
    if body.startswith(b'\x1a\x45\xdf\xa3'):
        return 'EBML signature'
    if len(body) >= 8 and body[4:8] in (b'ftyp',b'styp',b'moof',b'mdat'):
        return 'ISO-BMFF box signature'
    if body.startswith(b'\x1f\x8b'):
        return 'gzip signature'
    if body.lstrip().startswith((b'{', b'[')):
        return 'JSON-like prefix (not validated)'
    for spacing in (188,192,204):
        for offset in range(min(4096,max(0,len(body)-spacing*4))):
            if all(body[offset+n*spacing] == 0x47 for n in range(5)):
                return 'five MPEG-TS-like sync bytes, spacing ' + str(spacing)
    return 'unidentified'


def inspect(pcap):
    streams = defaultdict(list)
    totals = Counter()
    clipped = set()
    syns = defaultdict(set)
    with pcap.open('rb') as stream:
        for _, _, frame in packets(stream):
            if len(frame) < 54 or frame[12:14] != b'\x08\x00':
                continue
            ip=frame[14:]; ihl=(ip[0]&15)*4; total=int.from_bytes(ip[2:4],'big')
            if ip[0]>>4 != 4 or ihl < 20 or total < ihl+20 or len(ip)<total or ip[9]!=6 or int.from_bytes(ip[6:8],'big')&0x3fff:
                continue
            tcp=ip[ihl:total]; sport,dport,seq=struct.unpack('!HHI',tcp[:8]); offset=(tcp[12]>>4)*4
            if sport != 80 or offset < 20 or offset > len(tcp):
                continue
            key=(ip[12:16],ip[16:20],sport,dport)
            if tcp[13]&2:
                syns[key].add(seq)
            payload=tcp[offset:]
            if not payload:
                continue
            if totals[key]+len(payload)>LIMIT:
                clipped.add(key)
                continue
            totals[key]+=len(payload)
            streams[key].append(((seq+bool(tcp[13]&2)) % 2**32,payload))
    result={'response_direction_streams':len(streams),'clipped_streams':len(clipped),'reused_tuple_streams_skipped':0,'overlap_conflict_bytes':0,'gap_count':0,'responses':[]}
    for key, segments in streams.items():
        if len(syns[key])>1:
            result['reused_tuple_streams_skipped']+=1
            continue
        runs,conflicts=merge(segments)
        result['overlap_conflict_bytes']+=conflicts
        result['gap_count']+=max(0,len(runs)-1)
        if conflicts:
            continue
        for run in runs:
            position=0
            while position<len(run):
                match=re.search(rb'HTTP/1\.[01] ([0-9]{3}) [^\r\n]*\r\n',run[position:])
                if not match:
                    break
                begin=position+match.start(); end=run.find(b'\r\n\r\n',begin)
                if end<0 or end-begin>65536:
                    break
                header=run[begin:end]
                lengths=re.findall(rb'(?im)^content-length:\s*([0-9]+)\s*$',header)
                transfer=bool(re.search(rb'(?im)^transfer-encoding:',header))
                entry={'status':int(match[1]),'transfer_encoding_present':transfer}
                if len(lengths)!=1 or transfer:
                    entry['body_analysis']='unsupported framing'
                    result['responses'].append(entry)
                    # Do not scan through a body of unknown framing.
                    break
                length=int(lengths[0]); body=run[end+4:end+4+length]
                entry.update(content_length=length,complete=len(body)==length,body_hint=body_hint(body),body_sha256=hashlib.sha256(body).hexdigest() if len(body)==length else None)
                result['responses'].append(entry)
                if len(body)!=length:
                    break
                position=end+4+length
    result['limits']='Only IPv4 TCP source port 80. Up to 32 MiB captured payload per direction tuple. No decompression or chunked/close-delimited decoding. Only unambiguous Content-Length bodies inspected. Tuple reuse seen via multiple SYN sequences is skipped. No cryptographic protocol identification.'
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pcap',type=Path)
    args=parser.parse_args()
    print(json.dumps(inspect(args.pcap),indent=2))
