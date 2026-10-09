# vSeeBox V6 MAX investigation

Determine the device's streaming transport, endpoint roles, and playback behavior through controlled observations. No stream protocol or provider has been established yet.

See [initial findings](docs/2026-09-23.md) for evidence and access limitations.

## First experiment

Confirm the box's Ethernet IP in its settings before using the address below. On the Optiplex, run three captures: idle at the home screen, opening the sports app, and playing one channel. Record the app/channel name and exact UTC times of each action, buffering event, and channel change. Repeat with another channel to distinguish shared control services from media delivery.

```bash
sudo python3 /home/sean/vseebox/scripts/capture.py --interface enp2s0 --target 192.168.50.130 --seconds 60 --label idle
sudo python3 /home/sean/vseebox/scripts/capture.py --interface enp2s0 --target 192.168.50.130 --seconds 60 --label sports-app-open
sudo python3 /home/sean/vseebox/scripts/capture.py --interface enp2s0 --target 192.168.50.130 --seconds 120 --label sports-playing
python3 -m unittest discover -s /home/sean/vseebox/tests -v
```

Each capture creates a private directory with PCAP and metadata including the command, UTC start, label, exit code, and tcpdump diagnostics. Capture is limited to the specified IP and at most ten minutes. Full packets may contain credentials or signed URLs: keep raw captures local and publish only reviewed findings. The local ignore rules exclude captures from Git.

## Analysis plan

Once Dellmicro access is available, inventory the installed tool versions. Use Wireshark/tshark to compare DNS, TLS SNI when visible, transport conversations, destination ports, byte rates, and connection timing across the three phases. Inspect visible HTTP content types and playlist/segment patterns if present. Encrypted traffic alone does not establish HLS, DASH, stream URLs, or a particular provider. Record observations separately from hypotheses, with packet numbers and capture hashes. Capture filters based on IPv4 will not include independently assigned IPv6 traffic; check addressing before interpreting missing activity.

Record commands, tool versions, capture identifiers, actual outputs, and limitations for every experiment. Do not commit raw credentials, cookies, device identifiers from application payloads, or reusable signed playback URLs.

The current Git work tree is `/home/sean`, not this subdirectory. Stage only explicit project paths; do not use `git add .` from the home directory.
