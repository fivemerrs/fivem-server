#!/usr/bin/env python3
"""Start Pinggy TCP+UDP tunnel for FiveM and stay alive."""
import os
import sys
import time


def write_urls(urls: list[str]) -> str:
    connect = ""
    for u in urls:
        raw = u.replace("tcp://", "").replace("udp://", "").replace("https://", "").replace("http://", "")
        if raw and ":" in raw:
            connect = raw
            break
    if not connect and urls:
        connect = urls[0].split("://")[-1]

    with open("pinggy-urls.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(urls))
        if connect:
            f.write(f"\nconnect={connect}\n")

    gh_out = os.environ.get("GITHUB_OUTPUT")
    if gh_out and connect:
        host = connect.rsplit(":", 1)[0]
        with open(gh_out, "a", encoding="utf-8") as f:
            f.write(f"connect_address={connect}\n")
            f.write(f"connect_host={host}\n")
            f.write(f"tunnel_backend=pinggy\n")

    print("========== PINGGY TUNNEL UP ==========")
    print("URLs:", urls)
    print(f"FiveM F8: connect {connect}")
    print("======================================")
    return connect


def main() -> int:
    token = os.environ.get("PINGGY_TOKEN", "").strip()
    if not token:
        print("ERROR: set PINGGY_TOKEN secret (free token from pinggy.io dashboard)", file=sys.stderr)
        return 1

    port = int(os.environ.get("LOCAL_PORT", "30120"))

    import pinggy

    print(f"[pinggy] starting TCP+UDP -> localhost:{port} ...")
    tunnel = pinggy.start_tunnel(
        forwardto=port,
        type="tcp",
        token=token,
        force=True,
        autoreconnect=True,
        udpforwardto=port,
    )
    write_urls(list(tunnel.urls or []))
    tunnel.wait()
    return 0


if __name__ == "__main__":
    sys.exit(main())
