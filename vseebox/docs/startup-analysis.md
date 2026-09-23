# Heat Live 818 startup capture analysis

This report supersedes the pending-access status in `startup-observation.md`. The user observed Heat Live reopening directly to channel 818, with a clear picture after approximately 6–7 seconds. The app-open timestamp was not measured, so that delay cannot be precisely aligned with the packet timeline.

## Evidence integrity

- Capture start: `2026-09-23T20:35:54.139445+00:00`.
- Local evidence: `private-captures/20260923T203554.139445Z/traffic.pcap`.
- SHA-256: `9a3a7fa7194189d15131c5b67ab987d750b3b04d012d9dee15a2e5a69374017a`.
- File size: 208,554,238 bytes.
- 220,935 packets written; 221,057 received by filter; zero kernel-reported drops. The counter difference does not establish end-to-end packet loss.
- Exit 124 is expected for the 180-second timeout.
- Original recorded frame bytes: 205,019,254; packet timestamp span: 178.525758 seconds.
- 255 remote IPv4 addresses; 343 remote-IP/port/transport groups, aggregating local ports.

## Observed startup sequence

Times are relative to capture metadata start, not app opening.

| Interval or event | Observation |
| --- | --- |
| 0–20 seconds | Only 790 original frame bytes across 13 packets |
| About 22.08 seconds | TXT DNS queries to a public resolver, across five domain suffixes |
| About 22.89 seconds | A/AAAA queries for `vtcc_authn2.vseego.com` |
| About 23.74 seconds | A/AAAA queries for `broker.4kfibretv.com` |
| 23.005 seconds | First complete packet-local HTTP request line |
| 23.155 seconds | First packet-leading HTTP response |
| 20–25 seconds | 5.42 MB of original frame bytes |
| 25–45 seconds | Five-second bins contain 13.43–20.21 MB each; download-heavy |
| 55–60 seconds | 3.30 MB outbound TCP payload bytes, including any retransmissions |

DNS names are observations, not verified service roles. In particular, names containing `authn` or `broker` do not prove authentication or broker semantics. TXT query labels and TXT answer values are omitted from the public record because their meaning and sensitivity are unknown. No external endpoints were probed or resolved by the analysis tools.

## Visible HTTP evidence

- 39 packet-local complete GET request lines.
- None of those request paths ends in `.m3u8`, `.mpd`, `.ts`, `.mp4`, or `.m4s` after removing the query string.
- 30 packet-leading responses: 27 status 200 and three status 404.
- The general summarizer found 14 packets containing the selected `application/octet-stream` Content-Type pattern.
- No HLS body prefix or three 188-byte-spaced MPEG-TS sync bytes were found in the first body fragment following complete response headers in a single packet.

Counts may include retransmissions. Some requests or headers can span packets and be missed. No TCP reassembly was performed. Generic binary content type and extensionless paths do not identify a codec, container, encryption method, or protocol. HTTP might carry control data or media; attribution remains unresolved. URLs, queries, cookies, payloads, and per-address summaries remain local.

## Interpretation

Startup combines observable DNS/HTTP activity with a large download burst, followed later by substantial outbound payload traffic. Along with the prior playback-versus-idle result, this supports playback-associated multi-endpoint activity. Peer-assisted media distribution is still a hypothesis. No usable playback URL, manifest, media format, or custom delivery protocol has been established.

Next analysis should reconstruct selected HTTP TCP conversations offline, preserving sequence gaps and deduplicating retransmissions, then inspect framing and body signatures. The present capture can support this work without another recording. Mapping sockets to Heat Live itself would require separate device/app evidence.

## Commands and validation

```bash
python3 vseebox/scripts/summarize.py vseebox/private-captures/20260923T203554.139445Z/traffic.pcap --target 192.168.50.130
python3 vseebox/scripts/startup.py vseebox/private-captures/20260923T203554.139445Z --target 192.168.50.130
python3 -m unittest discover -s vseebox/tests -v
```

DNS was inspected locally with `tcpdump -nn -r <capture> 'udp port 53'`; raw output was not published. Eight tests passed, including synthetic packet tests for timing, request suffix classification, payload redaction, split-request limits, PCAP endianness, truncation, and directional byte accounting. The timeline analyzer was also executed successfully against the actual startup capture.
