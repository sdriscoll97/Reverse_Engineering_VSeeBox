# Heat Live playback versus home-screen idle

## Result

Traffic fell by 99.984721% between the channel 818 playback capture and the later home-screen capture. None of the 26 playback endpoint groups carrying more than 1 MB appeared in the idle capture. This strongly associates the high-volume traffic with the playback state. Peer-assisted delivery remains a hypothesis, not an identified protocol.

| Metric | Heat Live channel 818 | Home screen |
| --- | ---: | ---: |
| Requested recording window | 120 seconds | 120 seconds |
| Packets written | 138,879 | 325 |
| Original frame bytes | 129,327,743 | 19,760 |
| Total frame rate | 8.621850 Mbps | 0.001317 Mbps |
| Classified inbound frame rate | 6.899718 Mbps | 0.000579 Mbps |
| Classified outbound frame rate | 1.722104 Mbps | 0.000677 Mbps |
| Remote IPv4 addresses | 187 | 19 |
| Remote-IP/port/transport groups | 255 | 19 |
| Groups carrying more than 1 MB | 26 | 0 |
| Kernel-reported capture drops | 0 | 0 |

Rates use the full requested 120-second windows, unlike the first report's first-to-last-packet duration. Ten remote IPv4 addresses appear in both captures. Endpoint groups aggregate local ports and are not connection counts. Frame bytes include protocol overhead and retransmissions; they are not video bitrate or useful payload volume.

## Idle evidence

- User confirmed home-screen state and completion of the recording. No app force-stop or process-state observation was performed.
- Start: `2026-09-23T20:29:23.201187+00:00`.
- Local capture: `private-captures/20260923T202923.201187Z/traffic.pcap`.
- SHA-256: `bc21ab51f7cab2446375c848695c3749efde47b002726c81250e37323aa6b815`.
- PCAP size: 24,984 bytes.
- Metadata: timeout exit 124; tcpdump reports 325 captured, 325 received by filter, zero dropped by kernel.
- Packet timestamp span: 118.386029 seconds. Silence before/after the first/last packet explains why this differs from the requested window; it does not indicate a failed recording.
- The minimal analyzer classified 307 packets into TCP endpoint groups; 18 packets remain unclassified. One possible TLS prefix was detected, but the heuristic alone does not establish encryption.
- Raw packets and per-address summaries remain private and local.

## Limits

These are two separate observations approximately thirteen minutes apart. They do not show the moment traffic stopped, prove every observed socket belongs to Heat Live, or prove the app stopped running in the background. Background traffic, channel-specific behavior, and elapsed time remain possible confounders. The capture covers the specified IPv4 address, not independently assigned IPv6 addresses. No streaming URL, playlist, hostname attribution, or delivery protocol has yet been established.

## Reproduce

Run from the repository root after making the private capture files available locally:

```bash
python3 vseebox/scripts/summarize.py vseebox/private-captures/20260923T202923.201187Z/traffic.pcap --target 192.168.50.130 > vseebox/private-captures/20260923T202923.201187Z/summary.json
python3 vseebox/scripts/compare.py vseebox/private-captures/20260923T201632.646349Z vseebox/private-captures/20260923T202923.201187Z
```

The comparison was executed successfully on both actual captures. The earlier six capture/parser tests remain applicable; no parser changes were made for this comparison.

## Next experiment: capture startup

Start a 180-second capture while still at the home screen. After about 15 seconds, open Heat Live and select channel 818, then leave it playing until capture completion. Record the actual app-open and first-picture times. This should include new connection setup and any visible startup discovery traffic missing from the steady-playback capture.

```bash
sudo python3 /home/sean/vseebox/scripts/capture.py --interface enp2s0 --target 192.168.50.130 --seconds 180 --label heat-live-818-startup
sudo chown -R sean:sean /home/sean/vseebox/private-captures
```
