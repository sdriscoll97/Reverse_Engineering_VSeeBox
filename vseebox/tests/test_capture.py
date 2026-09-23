import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('capture', Path(__file__).resolve().parents[1] / 'scripts/capture.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


class CaptureTests(unittest.TestCase):
    def test_filter_is_scoped_to_device(self):
        cmd = capture.command('enp2s0', '192.168.50.130', 60, Path('/tmp/a b.pcap'))
        self.assertEqual(cmd[-2:], ['host', '192.168.50.130'])
        self.assertIn('/tmp/a b.pcap', cmd)
        self.assertEqual(cmd[:3], ['timeout', '--signal=INT', '60'])

    def test_rejects_unbounded_capture(self):
        for duration in (0, -1, 601):
            with self.assertRaises(ValueError):
                capture.command('enp2s0', '192.168.50.130', duration, Path('x'))

    def test_rejects_filter_injection(self):
        with self.assertRaises(ValueError):
            capture.command('enp2s0', '192.168.50.130 or net 0/0', 60, Path('x'))
        with self.assertRaises(ValueError):
            capture.command('-i any', '192.168.50.130', 60, Path('x'))
