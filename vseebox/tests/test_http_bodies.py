from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from http_bodies import merge, body_hint


class ReassemblyTests(unittest.TestCase):
    def test_out_of_order_and_identical_retransmission(self):
        runs, conflicts=merge([(103,b'def'),(100,b'abcde'),(103,b'def')])
        self.assertEqual(runs,[b'abcdef'])
        self.assertEqual(conflicts,0)

    def test_gap_not_filled(self):
        self.assertEqual(merge([(100,b'abc'),(105,b'fg')]),([b'abc',b'fg'],0))

    def test_conflicting_overlap_reported(self):
        self.assertEqual(merge([(100,b'abc'),(101,b'Xd')])[1],2)

    def test_sequence_wrap(self):
        self.assertEqual(merge([(2**32-2,b'ab'),(0,b'cd')]),([b'abcd'],0))

    def test_format_signatures(self):
        self.assertEqual(body_hint(b'#EXTM3U\n'),'HLS-like text')
        self.assertEqual(body_hint(b'\0\0\0\x18ftyp'), 'ISO-BMFF box signature')
        self.assertIn('188',body_hint((b'G'+b'\0'*187)*5))
        self.assertEqual(body_hint(b'unknown'),'unidentified')
