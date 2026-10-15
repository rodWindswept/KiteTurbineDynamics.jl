#!/usr/bin/env python3
"""Probe an MCP server: list tools, optionally run calls from a JSON spec.

Usage:
  mcp_probe.py stdio '<json-array cmd>' [calls.json]
  mcp_probe.py http '<url>' [calls.json]

calls.json: [{"tool": str, "args": {...}, "pace": float(optional)}]
Output: JSON to stdout. Progress notes to stderr.
"""
import asyncio
import json
import os
import sys
import time
from contextlib import AsyncExitStack

try:
    from mcp import ClientSession, StdioServerParameters
except ImportError:  # older SDK layout
    from mcp import ClientSession
    from mcp.client.stdio import StdioServerParameters


async def call_with_retry(session, name, args, tries=3):
    last = None
    for i in range(tries):
        try:
            return await asyncio.wait_for(session.call_tool(name, args), timeout=180)
        except Exception as e:  # noqa: BLE001
            last = e
            msg = str(e).lower()
            if "rate" in msg or "429" in msg or "timeout" in msg:
                wait = 20 * (i + 1)
                print(f"retry {name} in {wait}s: {e}", file=sys.stderr, flush=True)
                await asyncio.sleep(wait)
            else:
                break
    raise last


def result_to_dict(res):
    out = {"isError": bool(getattr(res, "isError", getattr(res, "is_error", False))), "content": []}
    for c in (getattr(res, "content", None) or []):
        t = getattr(c, "text", None)
        if t is None and isinstance(c, dict):
            t = c.get("text")
        if t is not None:
            out["content"].append({"type": "text", "text": t})
        else:
            out["content"].append({"repr": str(c)[:3000]})
    sc = getattr(res, "structuredContent", None) or getattr(res, "structured_content", None)
    if sc:
        out["structured"] = sc
    if not out["content"]:
        try:
            out["raw"] = res.model_dump()
        except Exception:  # noqa: BLE001
            out["raw"] = repr(res)[:3000]
    return out


def tool_to_dict(tool):
    raw = {}
    try:
        raw = tool.model_dump()
    except Exception:  # noqa: BLE001
        pass
    name = getattr(tool, "name", None) or raw.get("name")
    desc = getattr(tool, "description", None) or raw.get("description") or ""
    schema = (
        getattr(tool, "inputSchema", None)
        or getattr(tool, "input_schema", None)
        or raw.get("inputSchema")
        or raw.get("input_schema")
        or {}
    )
    return {"name": name, "description": desc[:300], "inputSchema": schema}


def http_client_factory():
    import mcp.client.streamable_http as sth
    for attr in ("streamablehttp_client", "streamable_http_client"):
        fn = getattr(sth, attr, None)
        if fn is not None:
            return fn
    names = [n for n in dir(sth) if "client" in n.lower()]
    raise ImportError(f"no streamable-http client in {sth.__file__}: {names}")


async def main():
    sys.stdout.reconfigure(encoding="utf-8")
    mode = sys.argv[1]
    calls = []
    if len(sys.argv) > 3:
        with open(sys.argv[3], encoding="utf-8") as fh:
            calls = json.load(fh)
    async with AsyncExitStack() as stack:
        if mode == "stdio":
            cmd = json.loads(sys.argv[2])
            env = dict(os.environ)
            params = StdioServerParameters(command=cmd[0], args=cmd[1:], env=env)
            from mcp.client.stdio import stdio_client
            read, write = await stack.enter_async_context(stdio_client(params))
        else:
            fn = http_client_factory()
            conn = await stack.enter_async_context(fn(sys.argv[2]))
            read, write = conn[0], conn[1]
        session = await stack.enter_async_context(ClientSession(read, write))
        await session.initialize()
        tl = await session.list_tools()
        out = {"tools": [tool_to_dict(t) for t in tl.tools]}
        if calls:
            out["results"] = []
            for c in calls:
                t0 = time.time()
                rec = {"tool": c["tool"], "args": c.get("args", {})}
                try:
                    res = await call_with_retry(session, c["tool"], c.get("args", {}))
                    rec["ms"] = int((time.time() - t0) * 1000)
                    rec["result"] = result_to_dict(res)
                except Exception as e:  # noqa: BLE001
                    rec["ms"] = int((time.time() - t0) * 1000)
                    rec["error"] = f"{type(e).__name__}: {e}"
                out["results"].append(rec)
                print(f"called {c['tool']} ({rec['ms']}ms)", file=sys.stderr, flush=True)
                await asyncio.sleep(float(c.get("pace", 1.2)))
        print(json.dumps(out, ensure_ascii=False, default=str))


asyncio.run(main())
