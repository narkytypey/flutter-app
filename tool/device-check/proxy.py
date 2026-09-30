#!/usr/bin/env python3
"""A logging upstream proxy for device checks: SOCKS5 and HTTP CONNECT.

Runs on the host. The emulator reaches it at 10.0.2.2, so a site set to
SOCKS5 10.0.2.2:1080 or HTTP 10.0.2.2:8888 goes through it. Every request is
logged with its target exactly as the app sent it, so a hostname and an
address are told apart (Plan 13 check 2: "SOCKS5 receives hostnames, never
addresses").

    python proxy.py                      # SOCKS5 on :1080, CONNECT on :8888
    python proxy.py --socks 0 --http 8888  # 0 turns a listener off

Standard library only, so it runs unchanged on Windows. No authentication:
the app sends none upstream (Plan 10).
"""
import argparse
import ipaddress
import socket
import struct
import threading
import time

ATYP_NAME = {1: "IPv4", 3: "NAME", 4: "IPv6"}
_print_lock = threading.Lock()


def log(message):
    with _print_lock:
        print(f"{time.strftime('%H:%M:%S')}.{int(time.time() * 1000) % 1000:03d} {message}", flush=True)


def read_exactly(sock, n):
    data = b""
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk:
            raise EOFError("eof")
        data += chunk
    return data


def pump(src, dst):
    try:
        while True:
            data = src.recv(16384)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def relay(client, upstream, label):
    started = time.time()
    back = threading.Thread(target=pump, args=(upstream, client), daemon=True)
    back.start()
    pump(client, upstream)
    back.join()
    client.close()
    upstream.close()
    log(f"{label} closed after {time.time() - started:.1f}s")


def handle_socks(client, peer):
    label = f"SOCKS5 from {peer[0]}:{peer[1]}"
    try:
        version, methods = read_exactly(client, 2)
        read_exactly(client, methods)
        if version != 5:
            log(f"{label} error: version {version}")
            return client.close()
        client.sendall(b"\x05\x00")
        _, command, _, atyp = read_exactly(client, 4)
        if atyp == 1:
            host = socket.inet_ntop(socket.AF_INET, read_exactly(client, 4))
        elif atyp == 3:
            host = read_exactly(client, read_exactly(client, 1)[0]).decode("ascii", "replace")
        elif atyp == 4:
            host = socket.inet_ntop(socket.AF_INET6, read_exactly(client, 16))
        else:
            log(f"{label} error: address type {atyp}")
            return client.close()
        (port,) = struct.unpack("!H", read_exactly(client, 2))
    except (EOFError, OSError) as error:
        # The app's ProxyProbe opens a socket and closes it: that is this line.
        log(f"{label} error {error} (a reachability probe, if nothing else follows)")
        return client.close()

    target = f"[{host}]:{port}" if atyp == 4 else f"{host}:{port}"
    label = f"SOCKS5 {ATYP_NAME.get(atyp, atyp)} {target}"
    if command != 1:
        log(f"{label} refused: command {command}")
        client.sendall(b"\x05\x07\x00\x01" + bytes(6))
        return client.close()
    log(label)
    try:
        upstream = socket.create_connection((host, port), timeout=20)
        upstream.settimeout(None)
    except OSError as error:
        log(f"{label} upstream failed: {error}")
        client.sendall(b"\x05\x05\x00\x01" + bytes(6))
        return client.close()
    client.sendall(b"\x05\x00\x00\x01" + bytes(6))
    relay(client, upstream, label)


def handle_http(client, peer):
    label = f"HTTP from {peer[0]}:{peer[1]}"
    head = b""
    try:
        while b"\r\n\r\n" not in head:
            chunk = client.recv(4096)
            if not chunk:
                raise EOFError("eof")
            head += chunk
            if len(head) > 65536:
                raise EOFError("head too large")
    except (EOFError, OSError) as error:
        log(f"{label} error {error} (a reachability probe, if nothing else follows)")
        return client.close()

    request_line = head.split(b"\r\n", 1)[0].decode("latin-1")
    parts = request_line.split(" ")
    if len(parts) != 3 or parts[0] != "CONNECT":
        log(f"{label} refused: {request_line!r}")
        client.sendall(b"HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        return client.close()
    target = parts[1]
    label = f"CONNECT {target}"
    host, _, port = target.rpartition(":")
    host = host.strip("[]")
    log(label)
    try:
        upstream = socket.create_connection((host, int(port)), timeout=20)
        upstream.settimeout(None)
    except (OSError, ValueError) as error:
        log(f"{label} upstream failed: {error}")
        client.sendall(b"HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        return client.close()
    client.sendall(b"HTTP/1.1 200 Connection established\r\n\r\n")
    # Anything the client sent after the head is already tunnel payload.
    extra = head.split(b"\r\n\r\n", 1)[1]
    if extra:
        upstream.sendall(extra)
    relay(client, upstream, label)


def serve(port, handler, name, bind):
    server = socket.create_server((bind, port), reuse_port=False)
    log(f"{name} listening on {bind}:{port}")
    while True:
        client, peer = server.accept()
        threading.Thread(target=handler, args=(client, peer), daemon=True).start()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--socks", type=int, default=1080, help="SOCKS5 port, 0 for none (default 1080)")
    parser.add_argument("--http", type=int, default=8888, help="HTTP CONNECT port, 0 for none (default 8888)")
    parser.add_argument("--bind", default="127.0.0.1",
                        help="address to listen on (default 127.0.0.1, which the emulator reaches as 10.0.2.2)")
    args = parser.parse_args()
    ipaddress.ip_address(args.bind)
    threads = []
    if args.socks:
        threads.append(threading.Thread(target=serve, args=(args.socks, handle_socks, "SOCKS5", args.bind), daemon=True))
    if args.http:
        threads.append(threading.Thread(target=serve, args=(args.http, handle_http, "HTTP CONNECT", args.bind), daemon=True))
    for thread in threads:
        thread.start()
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
