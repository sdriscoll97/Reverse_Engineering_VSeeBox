#!/usr/bin/env python3
"""Logging HTTP proxy: logs every request (method, host, path, headers, body snippet)
and CONNECT targets, then forwards traffic. Plain-HTTP requests are logged in full;
HTTPS CONNECTs are logged by target (tunnel is opaque without a MITM CA).

Usage: python3 logging_proxy.py [port] [logfile]
Then point the VSeeBox's wifi proxy at this PC: <pc-ip>:<port>
"""
import socket, threading, sys, select
from urllib.parse import urlsplit

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
LOGPATH = sys.argv[2] if len(sys.argv) > 2 else '/home/sean/firstproject/heatlive_apks/proxy.log'
LOG = open(LOGPATH, 'a', buffering=1)

def log(msg):
    LOG.write(msg + '\n')
    print(msg, flush=True)

def pipe(a, b):
    try:
        while True:
            r, _, _ = select.select([a, b], [], [], 60)
            if not r:
                break
            for s in r:
                data = s.recv(65536)
                if not data:
                    return
                (b if s is a else a).sendall(data)
    except Exception:
        pass
    finally:
        for s in (a, b):
            try: s.close()
            except Exception: pass

def handle(client):
    try:
        req = b''
        while b'\r\n\r\n' not in req:
            chunk = client.recv(65536)
            if not chunk:
                return
            req += chunk
            if len(req) > 1_000_000:
                break
        head, _, rest = req.partition(b'\r\n\r\n')
        lines = head.decode(errors='replace').split('\r\n')
        parts = lines[0].split(' ', 2)
        method, target = parts[0], parts[1] if len(parts) > 1 else ''

        if method == 'CONNECT':
            log(f'CONNECT {target}')
            host, port = target.rsplit(':', 1)
            upstream = socket.create_connection((host, int(port)), timeout=15)
            client.sendall(b'HTTP/1.1 200 Connection Established\r\n\r\n')
            if rest:
                upstream.sendall(rest)
            threading.Thread(target=pipe, args=(client, upstream), daemon=True).start()
            return

        # resolve host: absolute-form (proxy) or Host header
        host = None
        if target.startswith('http://') or target.startswith('https://'):
            host = urlsplit(target).hostname
        for l in lines[1:]:
            if l.lower().startswith('host:'):
                host = l.split(':', 1)[1].strip()
        log(f'{method} {target}  [host={host}]')
        interesting = [l for l in lines[1:] if any(k in l.lower() for k in
                     ('authorization', 'token', 'cookie', 'user-agent', 'content-type', 'x-'))]
        if interesting:
            log('    hdrs: ' + ' | '.join(interesting[:10]))
        if rest:
            snippet = rest[:600].decode(errors='replace').replace('\r', '').replace('\n', ' ')
            log(f'    body[{len(rest)}B]: {snippet}')

        if not host:
            client.close()
            return
        upstream = socket.create_connection((host, 80), timeout=15)
        upstream.sendall(req)
        threading.Thread(target=pipe, args=(client, upstream), daemon=True).start()
    except Exception as e:
        log(f'ERR {e}')
        try: client.close()
        except Exception: pass

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('0.0.0.0', PORT))
srv.listen(64)
log(f'[*] logging proxy on 0.0.0.0:{PORT} -> {LOGPATH}')
while True:
    c, _ = srv.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
