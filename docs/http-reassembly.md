# Startup HTTP reassembly follow-up

Analyzed the same startup capture identified in `startup-analysis.md` with `scripts/http_bodies.py`. This is passive offline analysis; no remote requests were made.

## Results

- Three response-direction TCP tuples with source port 80 contained payload.
- No clipping at the per-tuple 32 MiB capture limit; no detected sequence gaps, conflicting overlapping bytes, or tuple reuse indicated by multiple SYN sequence numbers.
- Reconstructed 21 complete Content-Length-framed status-200 response bodies.
- Largest body: 14,848,647 bytes. Other bodies include repeated 32-byte responses and bodies ranging from hundreds to thousands of bytes.
- One additional status-404 response used Transfer-Encoding framing; the analyzer stopped processing that contiguous run at that response rather than guessing later boundaries.
- All 21 inspected bodies remain unidentified by the limited format checks (HLS text prefix, FLV, EBML, ISO-BMFF prefix, gzip prefix, JSON-like prefix, and five regularly spaced MPEG-TS-like sync bytes near the start).

The large body is not established to be video: it could be application data or another resource. Unrecognized bytes do not establish encryption. Repeated small responses do not establish authentication semantics. Captured bodies, their hashes, and all URLs remain in local analysis only.

## Method and limits

The script sorts TCP payload by sequence offset, handles sequence wrap near the chosen anchor, merges identical overlaps, preserves gaps as separate runs, and skips tuples with conflicting overlaps. It considers IPv4 TCP source port 80 only and uses a 32 MiB captured-payload limit per direction tuple. Distinct SYN sequence numbers flag observable tuple reuse. Missing handshakes can leave reuse undetected. Sequence offsets assume a span under 2 GiB, appropriate for these bounded captures.

Only responses with exactly one Content-Length and no Transfer-Encoding are inspected. No decompression, chunked decoding, close-delimited body analysis, or application-layer decryption is performed. Counts therefore differ from the packet-local HTTP count in the startup report. Body classification is heuristic, not a media decoder.

```bash
python3 vseebox/scripts/http_bodies.py vseebox/private-captures/20260923T203554.139445Z/traffic.pcap
python3 -m unittest discover -s vseebox/tests -v
```

All 13 tests pass. New tests cover out-of-order delivery with retransmissions, preservation of gaps, conflicting overlap detection, sequence-number wrap, and format signatures. Actual-capture execution completed successfully. Tests do not establish correctness for arbitrary network traffic or all HTTP framing variants.

## Next useful evidence

The capture establishes plain HTTP binary transfers at startup and substantial traffic on other ports during playback. Mapping those binary bodies and high-port exchanges to the Heat Live application's implementation is now more useful than repeating an identical channel recording. App package/version identification and static inspection on Dellmicro would support that correlation. No app package has yet been acquired or inspected.
