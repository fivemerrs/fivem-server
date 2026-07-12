#!/usr/bin/env python3
"""Start Pinggy TCP+UDP tunnel; write connect address ASAP."""
import os
import sys
import traceback


def write_urls(urls) -> str:
    urls = [str(u) for u in (urls or [])]
    connect = ""
    for u in urls:
        raw = (
            u.replace("tcp://", "")
            .replace("udp://", "")
            .replace("https://", "")
            .replace("http://", "")
        )
        if ":" in raw and not raw.startswith("["):
            connect = raw
            break
        if raw.startswith("[") and "]:" in raw:
            connect = raw
            break
    if not connect and urls:
        connect = urls[0].split("://")[-1]

    with open("pinggy-urls.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(urls) + "\n")
        if connect:
            f.write(f"connect={connect}\n")

    gh = os.environ.get("GITHUB_OUTPUT")
    if gh and connect:
        host = connect.rsplit(":", 1)[0]
        with open(gh, "a", encoding="utf-8") as f:
            f.write(f"connect_address={connect}\n")
            f.write(f"connect_host={host}\n")
            f.write("tunnel_backend=pinggy\n")

    print("========== PINGGY TUNNEL UP ==========", flush=True)
    print("URLs:", urls, flush=True)
    print(f"FiveM F8: connect {connect}", flush=True)
    print("======================================", flush=True)
    return connect


def main() -> int:
    token = os.environ.get("PINGGY_TOKEN", "").strip()
    if not token:
        print("ERROR: PINGGY_TOKEN missing", flush=True)
        return 1

    port = int(os.environ.get("LOCAL_PORT", "30120"))
    print(f"[pinggy] import sdk...", flush=True)
    try:
        import pinggy
    except Exception:
        traceback.print_exc()
        return 1

    print(f"[pinggy] TCP+UDP -> 127.0.0.1:{port} token={token[:4]}...", flush=True)
    try:
        tunnel = pinggy.start_tunnel(
            forwardto=f"127.0.0.1:{port}",
            type="tcp",
            token=token,
            force=True,
            autoreconnect=True,
            udpforwardto=port,
            serveraddress="a.pinggy.io:443",
        )
    except Exception as e:
        print(f"[pinggy] TCP+UDP failed: {e}", flush=True)
        traceback.print_exc()
        print("[pinggy] fallback TCP-only...", flush=True)
        try:
            tunnel = pinggy.start_tunnel(
                forwardto=f"127.0.0.1:{port}",
                type="tcp",
                token=token,
                force=True,
                autoreconnect=True,
                serveraddress="a.pinggy.io:443",
            )
        except Exception:
            traceback.print_exc()
            return 1

    urls = list(getattr(tunnel, "urls", None) or [])
    print(f"[pinggy] urls={urls}", flush=True)
    write_urls(urls)
    try:
        tunnel.wait()
    except Exception:
        traceback.print_exc()
    return 0


if __name__ == "__main__":
    sys.exit(main())
