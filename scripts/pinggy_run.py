#!/usr/bin/env python3
"""Pinggy same-tunnel TCP+UDP; only write connect when URL is real."""
from __future__ import annotations

import json
import os
import sys
import time
import traceback


def save(urls: list[str]) -> str:
    clean = []
    for u in urls:
        s = str(u).strip()
        while "\x1b[" in s:
            i = s.find("\x1b[")
            j = s.find("m", i)
            if j < 0:
                break
            s = s[:i] + s[j + 1 :]
        if s:
            clean.append(s)

    connect = ""
    for u in clean:
        raw = u
        for p in ("tcp://", "udp://", "https://", "http://"):
            if raw.lower().startswith(p):
                raw = raw[len(p) :]
        if ":" in raw and " " not in raw and "/" not in raw:
            connect = raw
            break

    if not connect:
        return ""

    with open("pinggy-urls.txt", "w", encoding="utf-8") as f:
        json.dump({"urls": clean, "connect": connect}, f, indent=2)
        f.write("\n")
    with open("connect.txt", "w", encoding="utf-8") as f:
        f.write(connect + "\n")

    gh = os.environ.get("GITHUB_OUTPUT")
    if gh:
        host = connect.rsplit(":", 1)[0]
        with open(gh, "a", encoding="utf-8") as f:
            f.write(f"connect_address={connect}\n")
            f.write(f"connect_host={host}\n")
            f.write("tunnel_backend=pinggy\n")

    print(f"URLS={json.dumps(clean)}", flush=True)
    print(f"CONNECT={connect}", flush=True)
    print(f"FiveM F8: connect {connect}", flush=True)
    return connect


def main() -> int:
    token = os.environ["PINGGY_TOKEN"].strip()
    port = int(os.environ.get("LOCAL_PORT", "30120"))
    print(f"[pinggy] SDK TCP+UDP port={port}", flush=True)
    import pinggy

    tunnel = pinggy.start_tunnel(
        forwardto=port,
        type="tcp",
        token=token,
        force=True,
        autoreconnect=True,
        udpforwardto=port,
    )

    # Poll urls — start_tunnel should block until ready, but be safe
    connect = ""
    for i in range(30):
        urls = list(getattr(tunnel, "urls", None) or [])
        print(f"[pinggy] poll {i} urls={urls!r}", flush=True)
        connect = save(urls)
        if connect:
            break
        time.sleep(2)

    if not connect:
        print("[pinggy] ERROR: no public URL from SDK", flush=True)
        return 1

    tunnel.wait()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        traceback.print_exc()
        raise SystemExit(1)
