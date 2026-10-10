# VSeeBox Network Status — RESOLVED (2026-10-09)

Single source of truth for the current network setup between the Optiplex (analysis PC)
and the VSeeBox Android TV box. Supersedes `complete_network_solution.md`,
`network_solution_plan.md`, and `network_troubleshooting.md` (kept as history).

## Topology

Both devices plug into the same **network switch**, which also uplinks to the home
router. That is one flat layer-2 broadcast domain on the home LAN:

```
            ┌──────────── home router ────────────┐
            │  gateway 192.168.1.254              │
            └───────────────┬─────────────────────┘
                            │ (switch uplink)
                     ┌──────┴──────┐
                     │   switch    │  (L2, single broadcast domain)
                     └──┬───────┬──┘
                        │       │
              ┌─────────┘       └──────────┐
              │ enp2s0                   │ ethernet
        ┌─────┴────────┐           ┌─────┴──────────┐
        │   Optiplex   │           │    VSeeBox     │
        │ 192.168.1.168│           │ 192.168.1.163  │
        │  (analysis)  │           │ 192.168.1.167  │
        └──────────────┘           └────────────────┘
```

## Current addresses

| Device | Interface | Address | Notes |
|--------|-----------|---------|-------|
| Optiplex (analysis PC) | `enp2s0` | `192.168.1.168/24` | DHCP, gateway `192.168.1.254` |
| VSeeBox | ethernet | `192.168.1.163` | ping 0% loss |
| VSeeBox | ethernet | `192.168.1.167` | ping 0% loss |
| VSeeBox | — | MAC `b4:5b:d6:b1:8d:36` | recorded in `findings.md` (device MAC / MQTT client ID) |

The box currently answers on **two** IPs that share one MAC (`b4:5b:d6:b1:8d:36`) —
typical of an Android box holding a static address plus a DHCP lease on the same
interface. Treat both as the same device.

## How the box was identified

1. `192.168.50.130` (old static) stopped answering ARP → confirmed the box left the
   old `192.168.50.0/24` segment.
2. An ARP ping-sweep of `192.168.1.0/24` found 9 live hosts. Vendor lookups resolved
   all but one: MAC `b4:5b:d6:b1:8d:36` on `.163` and `.167`, with no open TCP ports
   (expected — ADB-over-TCP is off).
3. That MAC exactly matches the device MAC recorded in `findings.md` (used as the
   MQTT client ID / username). **Definitive match.**

## Device address history

| When | Address | Network |
|------|---------|---------|
| earliest docs | `10.42.0.130` | old lab network |
| mid-project | `192.168.50.130` | separate `192.168.50.0/24` segment |
| **now (2026-10-09)** | `192.168.1.163`, `192.168.1.167` | home `192.168.1.0/24` via switch |

Because the IP is not stable, **identify the box by MAC, not a hardcoded IP.**

## Discovery / verification tool

`vseebox/scripts/ping_vseebox.py` discovers the box by its MAC across all
directly-connected subnets and pings whatever address(es) currently map to it, so it
self-heals when the DHCP address changes:

```bash
python3 vseebox/scripts/ping_vseebox.py
```

## Cleanup performed (2026-10-09)

- Removed the dead secondary address `192.168.50.100/24` from `enp2s0`
  (`sudo ip addr del 192.168.50.100/24 dev enp2s0`). The Optiplex now carries only
  `192.168.1.168/24`; the default route via `192.168.1.254` is intact.
- Re-verified the box is reachable afterward.

## ADB / root-access gate (current blocker)

- TCP `5555` (adb) and `5037` are **closed** on both `192.168.1.163` and `192.168.1.167`.
  Expected — ADB-over-TCP is not enabled on the device.
- **Next step (on the device):** Settings → About → tap *Build* 7× → Developer Options →
  enable *USB debugging* (and *Network/Wireless debugging* if present).
- Then from the Optiplex:
  ```bash
  adb connect 192.168.1.167:5555      # or 192.168.1.163:5555
  # or connect the box over USB and run: adb devices
  ```
- Once ADB answers, proceed with the BoxTools privilege-escalation path in
  `root_access_strategy.md` / `vseebox/root_setup_plan.md`.

## Capture target going forward

Use the MAC-discovered current address (prefer `192.168.1.167`), e.g.:

```bash
sudo python3 vseebox/scripts/capture.py --interface enp2s0 --target 192.168.1.167 --seconds 60 --label idle
```

Always confirm the target first with `python3 vseebox/scripts/ping_vseebox.py`.
When re-analyzing the **historical** 2026-09-23 pcaps, keep `--target 192.168.50.130`
— those captures were recorded on the old `192.168.50.0/24` network.
