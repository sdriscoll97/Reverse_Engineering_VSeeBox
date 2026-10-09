# Heat Live channel 818 — first playback observation

The user reports smooth playback on channel 818 in Heat Live. The box had been disconnected and reconnected before recording. Its observed Ethernet neighbor address remained unchanged. App attribution is based on the user's observation; no process-to-socket mapping was collected.

## Evidence

- Capture: `20260923T201632.646349Z/traffic.pcap`, kept locally under ignored `private-captures/`.
- SHA-256: `0f5dbc02522e1dfd4a3ce50ac8a5c3f48787e30a96c784de9fdf4df8a1178a77`.
- PCAP size: 131,549,831 bytes; 138,879 packet records.
- Packet timestamps span 119.971445 seconds, beginning 2026-09-23 around 20:16:32 UTC.
- tcpdump reports 138,903 packets received by filter and zero packets dropped by kernel. Filter-received and written totals differ by 24; these counters do not establish end-to-end losslessness.
- Exit 124 is the expected timeout result for this bounded capture.
- Recorded original frame bytes: 129,327,743, averaging 8.624 Mbps. This includes headers and retransmissions and is not the video encoding bitrate.
- Classified IPv4 TCP/UDP inbound frame bytes: 103,495,777 (6.901 Mbps).
- Classified IPv4 TCP/UDP outbound frame bytes: 25,831,558 (1.723 Mbps).
- 187 distinct remote IPv4 addresses; 255 remote-IP/remote-port/transport groups. These are not TCP connection counts: local ports are deliberately aggregated.
- TCP accounts for 129,226,265 frame bytes; UDP 101,070. Eight packets were not classified by the minimal parser.
- 26 endpoint groups each account for more than one million frame bytes. Dominant groups use TCP and high remote ports; remote addresses remain in the private summary.

## Interpretation and limits

Many high-volume endpoints plus substantial outbound traffic are consistent with peer-assisted distribution. This remains a hypothesis: one steady-playback capture cannot establish which sockets belong to Heat Live, whether payload is relayed media, or what protocol it uses. There is no idle baseline or channel-change comparison yet.

The packet-local classifier detected 67 possible TLS-record prefixes, but arbitrary binary data can match this heuristic. It found no packet-leading HTTP response, HLS playlist, three consecutive 188-byte MPEG-TS sync markers, or the selected media Content-Type strings. Absence of these hints does not exclude HLS/DASH, encrypted traffic, differently framed media, or headers split across TCP segments. No reassembly, decryption, hostname attribution, or endpoint ownership lookup was performed.

## Reproduction

```bash
python3 vseebox/scripts/summarize.py vseebox/private-captures/20260923T201632.646349Z/traffic.pcap --target 192.168.50.130
python3 -m unittest discover -s vseebox/tests -v
```

The summary prints only endpoint addresses, counts, sizes, and fixed protocol hints; raw payloads and playback URLs are not exported. All analysis runs locally. A dpkt installation was attempted through a project virtual environment but failed because Python ensurepip is unavailable. The implemented summarizer uses only Python's standard library and does not require that environment.

## Next controlled experiment

Collect an app-exited baseline, then a second capture beginning before Heat Live opens and continuing through channel 818 startup. Record exact action times. Compare traffic rates and endpoint-group counts to test whether the observed traffic follows playback. A separate channel-change experiment can then test endpoint reuse. Confirm capture permissions and IPv4 address before running. Keep original captures private.
