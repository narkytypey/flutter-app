#!/usr/bin/env python3
"""The app's own sockets on the device, read over adb.

    python app_sockets.py watch            # every socket the app opens, flagged
    python app_sockets.py watch --outside  # only sockets to anything but loopback
    python app_sockets.py port             # the loopback proxy's port
    python app_sockets.py probe            # Plan 13 check 5 against that port

`watch` samples every 0.2 s and prints each socket of the app's uid once,
again when its state changes, and `gone` once it has closed. Anything whose remote end is not loopback is
marked `** OUTSIDE LOOPBACK **`: with the loopback proxy in place, a
proxied site should make none (Plan 13 check 1), and a direct site's sockets
are made by the proxy, from the same uid. DNS does not show here (netd makes
those queries); use dns_log.py for it. Ctrl-C prints a summary.

Sockets are read from /proc/net/{tcp,tcp6,udp,udp6}, which carry the owning
uid, or from `ss -tuna -e` if /proc/net cannot be read. Run from any shell;
Python calls adb directly, so Git Bash's path conversion does not apply.
"""
import argparse
import ipaddress
import re
import subprocess
import sys
import time

PACKAGE = "com.mono.container"
TCP_STATES = {
    "01": "ESTAB", "02": "SYN-SENT", "03": "SYN-RECV", "04": "FIN-WAIT-1", "05": "FIN-WAIT-2",
    "06": "TIME-WAIT", "07": "CLOSE", "08": "CLOSE-WAIT", "09": "LAST-ACK", "0A": "LISTEN", "0B": "CLOSING",
}


def adb(*args, check=True):
    result = subprocess.run(["adb", *args], capture_output=True, text=True)
    if check and result.returncode != 0:
        sys.exit(f"adb {' '.join(args)} failed: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def app_uid(package):
    for line in adb("shell", "cmd", "package", "list", "packages", "-U", package).splitlines():
        match = re.fullmatch(r"package:(\S+) uid:(\d+)", line.strip())
        if match and match.group(1) == package:
            return int(match.group(2))
    sys.exit(f"{package} is not installed on the device adb sees")


def proc_address(text):
    """/proc/net's `HEX:PORT`: each 32-bit word of the address is little-endian."""
    address, port = text.split(":")
    raw = bytes.fromhex(address)
    words = b"".join(raw[i:i + 4][::-1] for i in range(0, len(raw), 4))
    ip = ipaddress.ip_address(words)
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped:
        ip = ip.ipv4_mapped
    return ip, int(port, 16)


def from_proc(uid):
    sockets = []
    for proto in ("tcp", "tcp6", "udp", "udp6"):
        out = adb("shell", "cat", f"/proc/net/{proto}", check=False)
        lines = out.splitlines()[1:]
        if not lines and "Permission denied" in out:
            return None
        for line in lines:
            fields = line.split()
            if len(fields) < 8 or int(fields[7]) != uid:
                continue
            local, remote = proc_address(fields[1]), proc_address(fields[2])
            state = TCP_STATES.get(fields[3], fields[3]) if proto.startswith("tcp") else "UDP"
            sockets.append((proto.rstrip("6"), state, local, remote))
    return sockets


def ss_address(text):
    host, _, port = text.rpartition(":")
    host = host.strip("[]").split("%")[0]
    if host == "*":
        host = "0.0.0.0"
    ip = ipaddress.ip_address(host)
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped:
        ip = ip.ipv4_mapped
    return ip, 0 if port == "*" else int(port)


def from_ss(uid):
    sockets = []
    for line in adb("shell", "ss", "-tuna", "-e").splitlines():
        if f"uid:{uid} " not in line + " ":
            continue
        fields = line.split()
        proto, state, local, remote = fields[0], fields[1], fields[4], fields[5]
        sockets.append((proto, state.upper().replace("UNCONN", "UDP"), ss_address(local), ss_address(remote)))
    return sockets


def read_sockets(uid, source):
    if source in ("auto", "proc"):
        sockets = from_proc(uid)
        if sockets is not None:
            return sockets
        if source == "proc":
            sys.exit("/proc/net cannot be read on this device; try --source ss")
    return from_ss(uid)


def is_loopback_or_unbound(ip):
    return ip.is_loopback or ip.is_unspecified


def fmt(endpoint):
    ip, port = endpoint
    return f"[{ip}]:{port}" if ip.version == 6 else f"{ip}:{port}"


def listen_ports(sockets):
    return sorted({local[1] for proto, state, local, _ in sockets
                   if proto == "tcp" and state == "LISTEN" and local[0] == ipaddress.ip_address("127.0.0.1")})


def watch(args):
    uid = app_uid(args.package)
    print(f"{args.package} uid {uid}; loopback listener(s): {listen_ports(read_sockets(uid, args.source)) or 'none'}", flush=True)
    seen, outside = {}, {}
    try:
        while True:
            now = time.strftime("%H:%M:%S")
            current = set()
            for proto, state, local, remote in read_sockets(uid, args.source):
                key = (proto, local, remote)
                current.add(key)
                if seen.get(key) == state:
                    continue
                seen[key] = state
                out = not is_loopback_or_unbound(remote[0])
                if out:
                    outside.setdefault(fmt(remote), now)
                if out or not args.outside:
                    mark = "** OUTSIDE LOOPBACK **" if out else ""
                    print(f"{now} {proto:3} {state:10} {fmt(local):>24} -> {fmt(remote):<26} {mark}", flush=True)
            # Closed: gone from the kernel's table. Problem 1's check watches for this.
            for key in [key for key in seen if key not in current]:
                del seen[key]
                proto, local, remote = key
                if not args.outside or not is_loopback_or_unbound(remote[0]):
                    print(f"{now} {proto:3} {'gone':10} {fmt(local):>24} -> {fmt(remote):<26}", flush=True)
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print(f"\n{len(outside)} remote endpoint(s) outside loopback" + (":" if outside else "."))
        for remote, first in outside.items():
            print(f"  {remote} (first seen {first})")


def port(args):
    ports = listen_ports(read_sockets(app_uid(args.package), args.source))
    if not ports:
        sys.exit("no loopback listener: is the app running and past the lock screen?")
    print(" ".join(map(str, ports)))
    return ports[0]


def probe(args):
    proxy = port(args)
    cases = [
        ("no credentials", "CONNECT example.com:443 HTTP/1.1\\r\\n\\r\\n", "407", 'realm="container"'),
        ("a credential no session owns", "CONNECT example.com:443 HTTP/1.1\\r\\nProxy-Authorization: Basic MDA6MDA=\\r\\n\\r\\n", "403", None),
        ("the Autofill host", "CONNECT content-autofill.googleapis.com:443 HTTP/1.1\\r\\n\\r\\n", "403", None),
    ]
    failed = 0
    for name, request, status, needle in cases:
        reply = adb("shell", f"printf '{request}' | toybox nc 127.0.0.1 {proxy}", check=False)
        first = reply.splitlines()[0].strip() if reply.strip() else "(no reply)"
        ok = first.split(" ")[1:2] == [status] and (needle is None or needle in reply)
        failed += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {name}: {first}" + ("" if ok else f" (expected {status})"))
    print("Now check that proxy.py logged nothing, and that `watch` showed no socket to example.com.")
    sys.exit(1 if failed else 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--package", default=PACKAGE)
    parser.add_argument("--source", choices=("auto", "proc", "ss"), default="auto")
    commands = parser.add_subparsers(dest="command", required=True)
    w = commands.add_parser("watch", help="print the app's sockets as they appear")
    w.add_argument("--outside", action="store_true", help="only sockets whose remote end is not loopback")
    w.add_argument("--interval", type=float, default=0.2)
    w.set_defaults(run=watch)
    commands.add_parser("port", help="print the loopback proxy's port").set_defaults(run=port)
    commands.add_parser("probe", help="Plan 13 check 5: strangers get 407 and 403").set_defaults(run=probe)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
