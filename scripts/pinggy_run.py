#!/usr/bin/env python3
"""Pinggy TCP+UDP for FiveM — write clean connect address."""
from __future__ import annotations

import json
import os
import sys
import traceback


def save(urls: list[str]) -> str:
    clean = []
    for u in urls:
        s = str(u).strip()
        # strip ansi
        while "\x1b[" in s:
            i = s.find("\x1b[")
            j = s.find("m", i)
            if j < 0:
                break
            s = s[:i] + s[j + 1 :]
        clean.append(s)

    connect = ""
    for u in clean:
        raw = u
        for p in ("tcp://", "udp://", "https://", "http://"):
            if raw.startswith(p):
                raw = raw[len(p) :]
        if ":" in raw and " " not in raw:
            connect = raw
            break
    if not connect and clean:
        connect = clean[0].split("://")[-1]

    with open("pinggy-urls.txt", "w", encoding="utf-8") as f:
        f.write(json.dumps({"urls": clean, "connect": connect}, indent=2))
        f.write("\n")
    with open("connect.txt", "w", encoding="utf-8") as f:
        f.write(connect + "\n")

    gh = os.environ.get("GITHUB_OUTPUT")
    if gh and connect:
        host = connect.rsplit(":", 1)[0]
        with open(gh, "a", encoding="utf-8") as f:
            f.write(f"connect_address={connect}\n")
            f.write(f"connect_host={host}\n")
            f.write("tunnel_backend=pinggy\n")

    print("URLS=" + json.dumps(clean), flush=True)
    print(f"CONNECT={connect}", flush=True)
    print(f"FiveM F8: connect {connect}", flush=True)
    return connect


def main() -> int:
    token = os.environ["PINGGY_TOKEN"].strip()
    port = int(os.environ.get("LOCAL_PORT", "30120"))
    print(f"[pinggy] start TCP+UDP :{port}", flush=True)
    import pinggy

    try:
        tunnel = pinggy.start_tunnel(
            forwardto=port,
            type="tcp",
            token=token,
            force=True,
            autoreconnect=True,
            udpforwardto=port,
        )
    except Exception as e:
        print(f"[pinggy] both failed: {e}", flush=True)
        traceback.print_exc()
        print("[pinggy] TCP only fallback", flush=True)
        tunnel = pinggy.start_tunnel(
            forwardto=port,
            type="tcp",
            token=token,
            force=True,
            autoreconnect=True,
        )

    urls = list(getattr(tunnel, "urls", None) or [])
    print(f"[pinggy] raw urls={urls!r}", flush=True)
    save(urls)
    tunnel.wait()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        traceback.print_exc()
        raise SystemExit(1)
