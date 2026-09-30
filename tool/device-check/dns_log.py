#!/usr/bin/env python3
"""A logging DNS forwarder for device checks.

Start the emulator with `-dns-server` pointed at the address this listens on,
and every name the device looks up is logged before it is forwarded. For a
proxied site the only names that may appear are its pages' `dns-prefetch`
hints (Plan 13 check 10; the accepted gap a2). Anything else is a leak.

    python dns_log.py                          # 127.0.0.1:53 -> 1.1.1.1:53
    python dns_log.py --upstream 192.168.1.1   # your router's resolver
    emulator -avd <name> -dns-server 127.0.0.1

UDP only. Port 53 may need an administrator shell on Linux or macOS; on
Windows it does not. Standard library only.
"""
import argparse
import socket
import struct
import threading
import time

QTYPE = {1: "A", 2: "NS", 5: "CNAME", 12: "PTR", 15: "MX", 16: "TXT", 28: "AAAA", 33: "SRV", 64: "SVCB", 65: "HTTPS"}
_print_lock = threading.Lock()


def log(message):
    with _print_lock:
        print(f"{time.strftime('%H:%M:%S')}.{int(time.time() * 1000) % 1000:03d} {message}", flush=True)


def question(packet):
    """The first question's name and type, or None for anything unparseable."""
    try:
        (count,) = struct.unpack("!H", packet[4:6])
        if count < 1:
            return None
        labels, offset = [], 12
        while True:
            length = packet[offset]
            if length == 0:
                offset += 1
                break
            if length & 0xC0:  # a pointer cannot appear in a query's first name
                return None
            labels.append(packet[offset + 1:offset + 1 + length].decode("ascii", "replace"))
            offset += 1 + length
        (qtype,) = struct.unpack("!H", packet[offset:offset + 2])
        return ".".join(labels) or ".", QTYPE.get(qtype, str(qtype))
    except (IndexError, struct.error):
        return None


def answer(server, packet, client, upstream, timeout):
    asked = question(packet)
    log(f"{asked[1]:5} {asked[0]}" if asked else f"unparseable query from {client[0]}")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as forward:
        forward.settimeout(timeout)
        try:
            forward.sendto(packet, upstream)
            reply, _ = forward.recvfrom(65535)
        except OSError as error:
            log(f"      upstream failed for {asked[0] if asked else '?'}: {error}")
            return
    server.sendto(reply, client)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--listen", default="127.0.0.1", help="address to listen on (default 127.0.0.1)")
    parser.add_argument("--port", type=int, default=53, help="port to listen on (default 53)")
    parser.add_argument("--upstream", default="1.1.1.1", help="resolver to forward to (default 1.1.1.1)")
    parser.add_argument("--upstream-port", type=int, default=53)
    parser.add_argument("--timeout", type=float, default=5.0)
    args = parser.parse_args()

    server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server.bind((args.listen, args.port))
    log(f"DNS listening on {args.listen}:{args.port}, forwarding to {args.upstream}:{args.upstream_port}")
    upstream = (args.upstream, args.upstream_port)
    try:
        while True:
            packet, client = server.recvfrom(65535)
            threading.Thread(target=answer, args=(server, packet, client, upstream, args.timeout), daemon=True).start()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
