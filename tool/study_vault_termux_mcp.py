#!/usr/bin/env python3
"""StudyDesk Termux MCP adapter, Python standard library only.

Install a session-configured copy using Settings > Termux agent access.
The token is private, local to this bridge session, and revoked on stop.
This adapter never opens SQLite or requires Android shared-storage access.
"""
import json
import os
from pathlib import Path
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

DEFAULT_URL = ""
DEFAULT_TOKEN = ""
URL = os.environ.get("STUDY_VAULT_BRIDGE_URL", DEFAULT_URL).rstrip("/")
TOKEN = os.environ.get("STUDY_VAULT_BRIDGE_TOKEN", DEFAULT_TOKEN)
MAX_FILE_BYTES = 256 * 1024 * 1024


class BridgeError(Exception):
    pass


def request(path, data=None, method=None):
    parsed = urllib.parse.urlsplit(URL)
    if parsed.scheme != "http" or parsed.hostname != "127.0.0.1" or not parsed.port or parsed.path or parsed.query or parsed.fragment or parsed.username:
        raise BridgeError("Use the local bridge URL from StudyDesk Settings.")
    if not TOKEN:
        raise BridgeError("Start Termux agent access in StudyDesk and copy setup again.")
    headers = {"Authorization": "Bearer " + TOKEN}
    if isinstance(data, dict):
        data = json.dumps(data, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if hasattr(data, "read"):
        headers["Content-Length"] = str(os.fstat(data.fileno()).st_size)
    req = urllib.request.Request(URL + path, data=data, headers=headers, method=method)
    # Never send a credential through an HTTP proxy or follow redirects.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    try:
        return urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect()).open(req, timeout=600)
    except urllib.error.HTTPError as exc:
        try:
            detail = json.loads(exc.read(4096)).get("error", "Bridge request failed.")
        except (ValueError, AttributeError):
            detail = "Bridge request failed."
        raise BridgeError(str(detail)) from None
    except (OSError, urllib.error.URLError):
        raise BridgeError("Cannot reach StudyDesk. Open the app, start the bridge, and copy setup again if it restarted. Check the library before retrying a write.") from None


def fetch(path, data=None):
    with request(path, data) as response:
        return json.load(response)


def call_tool(name, arguments):
    args = dict(arguments)
    if name == "get_file":
        ids = {key: args[key] for key in ("material_id", "book_id") if key in args}
        with request("/file?" + urllib.parse.urlencode(ids)) as response:
            filename = Path(urllib.parse.unquote(response.headers.get("X-Study-Vault-Filename", "document"))).name
            folder = Path(os.environ.get("STUDY_VAULT_DOWNLOAD_DIR", str(Path.home() / ".cache" / "study-vault"))) / str(uuid.uuid4())
            folder.mkdir(parents=True, mode=0o700)
            target = folder / (filename if filename not in ("", ".", "..") else "document")
            try:
                with target.open("xb") as output:
                    os.chmod(target, 0o600)
                    shutil.copyfileobj(response, output, length=1024 * 1024)
            except BaseException:
                target.unlink(missing_ok=True)
                raise
        return {"path": str(target), "bytes": target.stat().st_size}
    if name == "attach_file":
        path = Path(args.pop("path")).expanduser()
        if not path.is_file():
            raise BridgeError("Attachment path must be a file accessible inside Termux.")
        if path.stat().st_size > MAX_FILE_BYTES:
            raise BridgeError("Attachments must be at most 256 MiB.")
        args["file_name"] = path.name
        if args.get("apply") is True:
            with path.open("rb") as content:
                with request("/upload", content, method="POST") as response:
                    args["upload_id"] = json.load(response)["upload_id"]
    # No automatic retry: a dropped response might follow a successful write.
    return fetch("/call", {"name": name, "arguments": args, "request_id": str(uuid.uuid4())})["result"]


def handle(message):
    method = message.get("method")
    params = message.get("params") or {}
    if not isinstance(params, dict):
        raise ValueError("MCP params must be an object.")
    if method == "initialize":
        return {"protocolVersion": params.get("protocolVersion", "2025-06-18"),
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "study-vault-mobile", "version": "1.0.0"},
                "instructions": "Access the active StudyDesk library on this phone. Find IDs with library_overview or search_library. Writes preview by default. Show previews and apply only when the user authorizes. Never blindly repeat a write after a connection error. No deletion tools are exposed."}
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": fetch("/tools")["tools"]}
    if method == "tools/call":
        try:
            result = call_tool(params["name"], params.get("arguments") or {})
            return {"content": [{"type": "text", "text": result if isinstance(result, str) else json.dumps(result, ensure_ascii=False)}]}
        except (BridgeError, OSError, ValueError, KeyError, TypeError) as exc:
            return {"content": [{"type": "text", "text": str(exc)}], "isError": True}
    raise LookupError(method)


def main():
    for line in sys.stdin:
        try:
            message = json.loads(line)
            if not isinstance(message, dict) or "id" not in message:
                continue
            try:
                response = {"jsonrpc": "2.0", "id": message["id"], "result": handle(message)}
            except LookupError:
                response = {"jsonrpc": "2.0", "id": message["id"], "error": {"code": -32601, "message": "Method not found"}}
            except (BridgeError, OSError, ValueError, TypeError) as exc:
                response = {"jsonrpc": "2.0", "id": message["id"], "error": {"code": -32603, "message": str(exc)}}
            print(json.dumps(response, ensure_ascii=False), flush=True)
        except (ValueError, TypeError):
            continue


if __name__ == "__main__":
    main()
