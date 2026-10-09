# Heat Live channel 818 startup — observation pending packet analysis

The user reports that opening Heat Live returned directly to channel 818 and a clear picture appeared about 6–7 seconds after app opening. This is a user-estimated startup delay, not a packet-derived measurement. The exact app-open timestamp and compliance with the proposed 15-second pre-start delay have not yet been confirmed.

Observed the 180-second startup capture running at elapsed 133 seconds, with output at `private-captures/20260923T203554.139445Z/traffic.pcap`. A later process check showed no capture process. Its directory remains root-owned and unreadable to the analysis account, so exit metadata, packet counts, capture hash, and protocol findings are pending. No claim of successful capture is made until those are checked.
