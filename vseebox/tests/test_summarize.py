import importlib.util
import io
from pathlib import Path
import struct
import unittest

spec = importlib.util.spec_from_file_location('summarize', Path(__file__).resolve().parents[1] / 'scripts/summarize.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)


def pcap(frames, endian='<'):
    result = struct.pack(endian+'IHHIIII', 0xa1b2c3d4, 2, 4, 0, 0, 65535, 1)
    for i, frame in enumerate(frames):
        result += struct.pack(endian+'IIII', i+1, 0, len(frame), len(frame)) + frame
    return result


def frame(src, dst, payload=b''):
    tcp = struct.pack('!HHIIBBHHH', 40000, 50000, 0, 0, 0x50, 0x18, 100, 0, 0) + payload
    ip = struct.pack('!BBHHHBBH4s4s', 0x45, 0, 20+len(tcp), 0, 0, 64, 6, 0, src, dst)
    return b'\0'*12 + b'\x08\x00' + ip + tcp


class SummaryTests(unittest.TestCase):
    def test_endianness_and_direction(self):
        target=b'\xc0\xa8\x32\x82'; remote=b'\x01\x02\x03\x04'
        incoming=frame(remote,target,b'abc'); outgoing=frame(target,remote,b'defg')
        for endian in ('<','>'):
            report=s.summarize(io.BytesIO(pcap([incoming,outgoing],endian)),'192.168.50.130')
            self.assertEqual(report['packets'],2)
            self.assertEqual(report['duration_seconds'],1)
            self.assertEqual(sum(f.get('inbound_frame_bytes',0) for f in report['flows']),len(incoming))
            self.assertEqual(sum(f.get('outbound_frame_bytes',0) for f in report['flows']),len(outgoing))

    def test_truncation_fails(self):
        with self.assertRaises(ValueError):
            list(s.packets(io.BytesIO(pcap([b'abc'])[:-1])))

    def test_payload_not_exported(self):
        raw=frame(b'\x01\x02\x03\x04',b'\xc0\xa8\x32\x82',b'HTTP/1.1 200 OK\r\nCookie: secret-token\r\n\r\n')
        report=s.summarize(io.BytesIO(pcap([raw])),'192.168.50.130')
        self.assertNotIn('secret-token',str(report))
        self.assertEqual(report['packet_local_hints']['http_response_packet_prefix'],1)
