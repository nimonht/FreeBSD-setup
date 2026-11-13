#!/usr/bin/env python3
"""Drive a FreeBSD install ISO through QEMU's serial console like a person.
usage: drive.py SOCKET LOGFILE STEPS_JSON
STEPS_JSON: list of [wait_regex, send_text, timeout_seconds]; send_text may
use \\r, \\x1b etc. An empty wait_regex sends immediately."""
import json, re, socket, sys, time
sock_path, log_path, steps_path = sys.argv[1:4]
stop_after = '--stop' in sys.argv[4:]   # return after the last step instead of logging until exit
steps = json.load(open(steps_path))
s = None
for _ in range(120):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(sock_path); break
    except OSError:
        time.sleep(1)
s.settimeout(1.0)
log = open(log_path, 'ab', buffering=0)
buf = b''
def pump():
    global buf
    try:
        d = s.recv(65536)
        if d:
            log.write(d); buf += d
            buf = buf[-200000:]
    except socket.timeout:
        pass
def clean(b):
    t = b.decode('utf-8', 'replace')
    return re.sub(r'\x1b\[[0-9;?]*[A-Za-z]', '', t)
for i, (pat, send, tmo) in enumerate(steps):
    start = time.time()
    if pat:
        rx = re.compile(pat)
        while True:
            pump()
            if rx.search(clean(buf[-20000:])):
                break
            if time.time() - start > tmo:
                print(f'step {i}: timeout waiting for {pat!r}', flush=True); sys.exit(2)
        buf = b''
    print(f'step {i}: matched {pat!r} after {int(time.time()-start)}s; sending {send[:40]!r}', flush=True)
    for ch in send.encode():
        s.send(bytes([ch])); time.sleep(0.02)
if stop_after:
    sys.exit(0)
# keep logging until the VM exits
while True:
    try:
        d = s.recv(65536)
        if not d: break
        log.write(d)
    except socket.timeout:
        continue
    except OSError:
        break
