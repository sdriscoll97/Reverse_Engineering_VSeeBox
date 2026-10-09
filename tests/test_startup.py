import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from test_summarize import frame, pcap

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import startup


class StartupTests(unittest.TestCase):
    def test_timing_redaction_and_http_status(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / 'metadata.json').write_text(json.dumps({'started_utc': '1970-01-01T00:00:00+00:00'}))
            target=b'\xc0\xa8\x32\x82'; remote=b'\x01\x02\x03\x04'
            request=frame(target, remote, b'GET /secret-path/video.m3u8?token=private HTTP/1.1\r\nCookie: hidden\r\n\r\n')
            response=frame(remote, target, b'HTTP/1.1 200 OK\r\n\r\n#EXTM3U\n')
            (directory / 'traffic.pcap').write_bytes(pcap([request,response]))
            report = startup.analyze(directory, '192.168.50.130')
            self.assertEqual(report['first_observed']['http_request_seconds'],1)
            self.assertEqual(report['first_observed']['http_response_seconds'],2)
            self.assertEqual(report['http_request_packet_counts'], {'GET .m3u8':1})
            self.assertEqual(report['http_response_packet_counts']['body_hls_prefix'],1)
            self.assertEqual(report['bins'][0]['frame_bytes'],len(request)+len(response))
            for sensitive in ('secret-path','token=private','hidden'):
                self.assertNotIn(sensitive,json.dumps(report))

    def test_split_request_is_not_claimed(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / 'metadata.json').write_text('{"started_utc":"1970-01-01T00:00:00+00:00"}')
            partial=frame(b'\xc0\xa8\x32\x82',b'\x01\x02\x03\x04',b'GET /video.m3u8 HTTP/1.')
            (directory / 'traffic.pcap').write_bytes(pcap([partial]))
            self.assertEqual(startup.analyze(directory,'192.168.50.130')['http_request_packet_counts'],{})
