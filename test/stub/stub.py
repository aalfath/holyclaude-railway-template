# Test-only stand-in for the Anthropic Messages API (not part of the template).
# First call that offers the Write tool gets a tool_use asking to write a file;
# a call carrying the tool_result gets a plain text reply.
import json, os, socket, uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
TARGET = os.environ.get("WRITE_TARGET", "/workspace/demo/hello.txt")
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _json(self, code, obj):
        b = json.dumps(obj).encode(); self.send_response(code)
        self.send_header("content-type", "application/json"); self.send_header("content-length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self): self._json(200, {"ok": True, "data": []})
    def do_HEAD(self): self.send_response(200); self.end_headers()
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("content-length") or 0)) or b"{}")
        if "count_tokens" in self.path: return self._json(200, {"input_tokens": 10})
        if not self.path.startswith("/v1/messages"): return self._json(200, {})
        raw = json.dumps(body.get("messages", []))
        tools = [t.get("name") for t in body.get("tools", []) or []]
        mid = "msg_" + uuid.uuid4().hex[:20]; model = body.get("model", "claude-stub")
        if "tool_result" in raw:
            res = "denied" if ("denied" in raw.lower() or "permission" in raw.lower()) else "ok"
            print("stub: got tool_result", res, raw[-300:], flush=True)
            blocks = [{"type": "text", "text": "STUB-DONE " + res}]; stop = "end_turn"
        elif "Write" in tools:
            print("stub: asking for Write", TARGET, flush=True)
            blocks = [{"type": "tool_use", "id": "toolu_" + uuid.uuid4().hex[:20], "name": "Write", "input": {"file_path": TARGET, "content": "written by the stub\n"}}]; stop = "tool_use"
        else:
            blocks = [{"type": "text", "text": "STUB-REPLY"}]; stop = "end_turn"
        msg = {"id": mid, "type": "message", "role": "assistant", "model": model, "content": [], "stop_reason": None, "stop_sequence": None, "usage": {"input_tokens": 10, "output_tokens": 1}}
        if not body.get("stream"):
            msg.update(content=blocks, stop_reason=stop); return self._json(200, msg)
        self.send_response(200); self.send_header("content-type", "text/event-stream"); self.end_headers()
        def ev(t, d): self.wfile.write(f"event: {t}\ndata: {json.dumps(d)}\n\n".encode()); self.wfile.flush()
        ev("message_start", {"type": "message_start", "message": msg})
        for i, b in enumerate(blocks):
            if b["type"] == "text":
                ev("content_block_start", {"type": "content_block_start", "index": i, "content_block": {"type": "text", "text": ""}})
                ev("content_block_delta", {"type": "content_block_delta", "index": i, "delta": {"type": "text_delta", "text": b["text"]}})
            else:
                ev("content_block_start", {"type": "content_block_start", "index": i, "content_block": {"type": "tool_use", "id": b["id"], "name": b["name"], "input": {}}})
                ev("content_block_delta", {"type": "content_block_delta", "index": i, "delta": {"type": "input_json_delta", "partial_json": json.dumps(b["input"])}})
            ev("content_block_stop", {"type": "content_block_stop", "index": i})
        ev("message_delta", {"type": "message_delta", "delta": {"stop_reason": stop, "stop_sequence": None}, "usage": {"output_tokens": 8}})
        ev("message_stop", {"type": "message_stop"})
class S(ThreadingHTTPServer):
    address_family = socket.AF_INET6
    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0); super().server_bind()
S(("::", int(os.environ.get("PORT", "8080"))), H).serve_forever()
