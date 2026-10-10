#!/usr/bin/env python3
"""
Locate and ping the VSeeBox on the local network.

The box's IP is NOT stable: it moved off the old 192.168.50.0/24 segment onto the
home network and can hold more than one DHCP/static address at once. Rather than
hardcode an IP, we discover the device by its recorded hardware MAC and ping
whatever address(es) currently map to it.

Recorded device MAC (from findings.md, used as the MQTT client ID):
    b4:5b:d6:b1:8d:36
"""

import subprocess
import sys

# Authoritative hardware fingerprint for the VSeeBox.
VSEEBOX_MAC = "b4:5b:d6:b1:8d:36"

# Addresses to try if MAC discovery comes up empty (e.g. ARP not yet populated).
FALLBACK_IPS = [
    "192.168.1.163",   # observed on home network 2026-10-09
    "192.168.1.167",   # observed on home network 2026-10-09
    "192.168.50.130",  # legacy static from the old separate network
]


def local_subnets():
    """Return the list of directly-connected IPv4 subnets (CIDR) on this host."""
    out = subprocess.run(
        ["ip", "-o", "-4", "addr", "show"],
        capture_output=True, text=True, check=False,
    ).stdout
    subnets = []
    for line in out.splitlines():
        parts = line.split()
        if "inet" in parts:
            cidr = parts[parts.index("inet") + 1]
            if not cidr.startswith("127."):
                subnets.append((parts[1], cidr))  # (iface, cidr)
    return subnets


def sweep(cidr):
    """Best-effort ping sweep to populate the ARP/neighbour table."""
    if "/" not in cidr:
        return
    base = cidr.split("/")[0]
    prefix = base.rsplit(".", 1)[0]
    procs = []
    for host in range(1, 255):
        ip = f"{prefix}.{host}"
        procs.append(subprocess.Popen(
            ["ping", "-c", "1", "-W", "1", ip],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        ))
    for p in procs:
        try:
            p.wait(timeout=3)
        except subprocess.TimeoutExpired:
            p.kill()


def ips_for_mac(mac):
    """Return live IPs whose neighbour entry maps to the given MAC."""
    out = subprocess.run(
        ["ip", "neigh", "show"], capture_output=True, text=True, check=False,
    ).stdout
    ips = []
    for line in out.splitlines():
        low = line.lower()
        if mac in low and "failed" not in low:
            ips.append(line.split()[0])
    return ips


def ping(ip, count=2):
    r = subprocess.run(
        ["ping", "-c", str(count), "-W", "2", ip],
        capture_output=True, text=True, check=False,
    )
    return r.returncode == 0, r.stdout.strip()


def main():
    print("=== VSeeBox discovery (by MAC) ===")
    print(f"Target MAC: {VSEEBOX_MAC}\n")

    # Populate ARP for every directly-connected subnet.
    for iface, cidr in local_subnets():
        print(f"Sweeping {cidr} on {iface} ...")
        sweep(cidr)

    ips = ips_for_mac(VSEEBOX_MAC)

    if ips:
        print(f"\n✓ Found VSeeBox at: {', '.join(ips)}")
    else:
        print("\n! Box MAC not seen in ARP; falling back to known addresses.")
        ips = FALLBACK_IPS

    ok_any = False
    for ip in ips:
        ok, out = ping(ip)
        status = "REACHABLE" if ok else "unreachable"
        print(f"\n--- {ip}: {status} ---")
        if ok:
            ok_any = True
            print(out.splitlines()[-1] if out else "")

    print("\n=== Result ===")
    if ok_any:
        print("SUCCESS: VSeeBox is reachable on the local network.")
        print("Next phase: enable ADB-over-TCP / USB debugging on the device "
              "(ports 5555/5037 are closed until then).")
        return 0
    print("FAILED: could not reach the VSeeBox on any address.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
