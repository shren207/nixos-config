#!/usr/bin/env python3
import cgi
import hashlib
import json
import os
import re
import subprocess
import tempfile
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote, urlsplit

MAX_ASSET_SIZE_MB = int(os.environ.get("MAX_ASSET_SIZE_MB", "50"))
MAX_ASSET_SIZE_BYTES = MAX_ASSET_SIZE_MB * 1024 * 1024
KARAKEEP_BASE_URL = os.environ.get("KARAKEEP_BASE_URL", "http://127.0.0.1:3000").rstrip("/")
FALLBACK_DIR = os.environ.get("FALLBACK_DIR", "/mnt/data/archive-fallback")
COPYPARTY_FALLBACK_URL = os.environ.get(
    "COPYPARTY_FALLBACK_URL", "https://copyparty.greenhead.dev/archive-fallback/"
).rstrip("/") + "/"
LISTEN_HOST = os.environ.get("SINGLEFILE_BRIDGE_LISTEN", "127.0.0.1")
LISTEN_PORT = int(os.environ.get("SINGLEFILE_BRIDGE_PORT", "3010"))
REQUEST_TIMEOUT_SEC = int(os.environ.get("SINGLEFILE_BRIDGE_TIMEOUT_SEC", "240"))

PUSHOVER_TOKEN = os.environ.get("PUSHOVER_TOKEN", "")
PUSHOVER_USER = os.environ.get("PUSHOVER_USER", "")


def log(msg: str) -> None:
    print(msg, flush=True)


def shorten_url(url: str) -> str:
    short = re.sub(r"^https?://", "", url)
    short = short.split("?", 1)[0].rstrip("/")
    return short


def sanitize_filename(name: str) -> str:
    base = os.path.basename(name or "archive.html")
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", base).strip("._")
    if not cleaned:
        cleaned = "archive"
    if not re.search(r"\.(html?|xhtml)$", cleaned, flags=re.IGNORECASE):
        cleaned = f"{cleaned}.html"
    return cleaned


def build_fallback_name(source_url: str, original_name: str) -> str:
    parsed = urlsplit(source_url)
    host = re.sub(r"[^A-Za-z0-9.-]+", "-", parsed.netloc or "unknown").strip("-")
    path_slug = re.sub(r"[^A-Za-z0-9]+", "-", parsed.path or "").strip("-")
    if not path_slug:
        path_slug = "page"
    path_slug = path_slug[:40]
    digest = hashlib.sha256(source_url.encode("utf-8")).hexdigest()[:10]
    ts = time.strftime("%Y%m%d-%H%M%S", time.gmtime())
    ext = os.path.splitext(sanitize_filename(original_name))[1] or ".html"
    return f"{ts}-{host}-{path_slug}-{digest}{ext}"


def parse_content_type(headers) -> tuple[str, dict]:
    content_type = headers.get("Content-Type", "")
    ctype, pdict = cgi.parse_header(content_type)
    return ctype.lower(), pdict


def parse_response_headers(headers_path: str) -> str:
    content_type = "application/json"
    try:
        with open(headers_path, "r", encoding="utf-8", errors="ignore") as fp:
            for line in reversed(fp.readlines()):
                if line.lower().startswith("content-type:"):
                    content_type = line.split(":", 1)[1].strip()
                    break
    except OSError:
        pass
    return content_type


def run_curl(cmd: list[str]) -> tuple[int | None, bytes, str, str | None]:
    body_fd, body_path = tempfile.mkstemp(prefix="karakeep-bridge-body-")
    header_fd, header_path = tempfile.mkstemp(prefix="karakeep-bridge-header-")
    os.close(body_fd)
    os.close(header_fd)
    try:
        full_cmd = cmd + [
            "-D",
            header_path,
            "-o",
            body_path,
            "-w",
            "%{http_code}",
        ]
        result = subprocess.run(full_cmd, capture_output=True, text=True, timeout=REQUEST_TIMEOUT_SEC + 10)
        if result.returncode != 0:
            err = (result.stderr or result.stdout or "").strip()
            return None, b"", "application/json", f"curl failed: {err}"

        status_text = (result.stdout or "").strip()
        if not status_text.isdigit():
            return None, b"", "application/json", f"unexpected curl status output: {status_text}"

        status_code = int(status_text)
        with open(body_path, "rb") as fp:
            body = fp.read()
        content_type = parse_response_headers(header_path)
        return status_code, body, content_type, None
    except subprocess.TimeoutExpired:
        return None, b"", "application/json", "curl timeout"
    finally:
        for path in (body_path, header_path):
            try:
                os.unlink(path)
            except OSError:
                pass


def send_pushover(message: str, priority: int = 0) -> None:
    if not PUSHOVER_TOKEN or not PUSHOVER_USER:
        return
    cmd = [
        "curl",
        "-sf",
        "--proto",
        "=https",
        "--max-time",
        "10",
        "--form-string",
        f"token={PUSHOVER_TOKEN}",
        "--form-string",
        f"user={PUSHOVER_USER}",
        "--form-string",
        "title=Karakeep",
        "--form-string",
        f"message={message}",
        "--form-string",
        f"priority={priority}",
        "https://api.pushover.net/1/messages.json",
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


class SingleFileBridgeHandler(BaseHTTPRequestHandler):
    server_version = "KarakeepSingleFileBridge/1.0"

    def log_message(self, fmt: str, *args) -> None:
        log(f"{self.client_address[0]} - {fmt % args}")

    def respond_bytes(self, status: int, body: bytes, content_type: str = "application/json") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def respond_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.respond_bytes(status, body, "application/json; charset=utf-8")

    def do_GET(self) -> None:
        parsed = urlsplit(self.path)
        if parsed.path in ("/healthz", "/health"):
            self.respond_json(
                200,
                {
                    "status": "ok",
                    "maxAssetSizeMb": MAX_ASSET_SIZE_MB,
                    "fallbackDir": FALLBACK_DIR,
                },
            )
            return
        self.respond_json(404, {"error": "Not Found"})

    def do_POST(self) -> None:
        parsed = urlsplit(self.path)
        if parsed.path not in ("/api/v1/bookmarks/singlefile", "/"):
            self.respond_json(404, {"error": "Not Found"})
            return

        auth_header = (self.headers.get("Authorization") or "").strip()
        if not auth_header.lower().startswith("bearer "):
            self.respond_json(401, {"error": "Missing Bearer token"})
            return

        ctype, _ = parse_content_type(self.headers)
        if ctype != "multipart/form-data":
            self.respond_json(415, {"error": "Content-Type must be multipart/form-data"})
            return

        temp_path = None
        try:
            form = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ={
                    "REQUEST_METHOD": "POST",
                    "CONTENT_TYPE": self.headers.get("Content-Type", ""),
                    "CONTENT_LENGTH": self.headers.get("Content-Length", ""),
                },
                keep_blank_values=True,
            )

            file_item = form["file"] if "file" in form else None
            if isinstance(file_item, list):
                file_item = next((item for item in file_item if item.filename), file_item[0] if file_item else None)

            if file_item is None or getattr(file_item, "file", None) is None:
                self.respond_json(400, {"error": "Missing file field"})
                return

            fields: list[tuple[str, str]] = []
            for item in form.list or []:
                if item.filename is not None:
                    continue
                if not item.name:
                    continue
                fields.append((item.name, str(item.value)))

            source_url = ""
            for key, value in fields:
                if key == "url" and value.strip():
                    source_url = value.strip()
            if not source_url:
                self.respond_json(400, {"error": "Missing url field"})
                return

            original_name = sanitize_filename(getattr(file_item, "filename", "") or "archive.html")
            suffix = os.path.splitext(original_name)[1] or ".html"
            with tempfile.NamedTemporaryFile(
                delete=False, prefix="karakeep-singlefile-", suffix=suffix
            ) as temp_file:
                temp_path = temp_file.name
                file_size = 0
                while True:
                    chunk = file_item.file.read(1024 * 1024)
                    if not chunk:
                        break
                    temp_file.write(chunk)
                    file_size += len(chunk)

            if file_size <= MAX_ASSET_SIZE_BYTES:
                endpoint = f"{KARAKEEP_BASE_URL}/api/v1/bookmarks/singlefile"
                if parsed.query:
                    endpoint = f"{endpoint}?{parsed.query}"

                cmd = [
                    "curl",
                    "-sS",
                    "--max-time",
                    str(REQUEST_TIMEOUT_SEC),
                    "-X",
                    "POST",
                    "-H",
                    f"Authorization: {auth_header}",
                    "-H",
                    "Accept: application/json",
                ]
                for key, value in fields:
                    cmd.extend(["--form-string", f"{key}={value}"])
                cmd.extend(["-F", f"file=@{temp_path};filename={original_name};type=text/html", endpoint])

                status, body, content_type, err = run_curl(cmd)
                if err:
                    self.respond_json(502, {"error": err})
                    return
                self.respond_bytes(status or 502, body, content_type)
                return

            os.makedirs(FALLBACK_DIR, exist_ok=True)
            fallback_name = build_fallback_name(source_url, original_name)
            fallback_path = os.path.join(FALLBACK_DIR, fallback_name)
            os.replace(temp_path, fallback_path)
            temp_path = None
            fallback_public_url = f"{COPYPARTY_FALLBACK_URL}{quote(fallback_name)}"

            payload = {"type": "link", "url": source_url}
            title_value = next((value.strip() for key, value in fields if key == "title" and value.strip()), "")
            if title_value:
                payload["title"] = title_value

            cmd = [
                "curl",
                "-sS",
                "--max-time",
                str(REQUEST_TIMEOUT_SEC),
                "-X",
                "POST",
                "-H",
                f"Authorization: {auth_header}",
                "-H",
                "Content-Type: application/json",
                "-H",
                "Accept: application/json",
                "--data",
                json.dumps(payload, ensure_ascii=False),
                f"{KARAKEEP_BASE_URL}/api/v1/bookmarks",
            ]
            status, body, content_type, err = run_curl(cmd)
            if err:
                send_pushover(
                    "\n".join(
                        [
                            f"대용량 분기 실패: {shorten_url(source_url)}",
                            f"원인: 링크 북마크 API 호출 실패 ({err})",
                            f"보관 파일: {fallback_public_url}",
                        ]
                    ),
                    0,
                )
                self.respond_json(
                    502,
                    {
                        "error": err,
                        "fallbackUrl": fallback_public_url,
                    },
                )
                return

            if status is None or status < 200 or status >= 300:
                send_pushover(
                    "\n".join(
                        [
                            f"대용량 분기 실패: {shorten_url(source_url)}",
                            "원인: 링크 북마크 생성 실패",
                            f"보관 파일: {fallback_public_url}",
                        ]
                    ),
                    0,
                )
                self.respond_bytes(status or 502, body, content_type)
                return

            send_pushover(
                "\n".join(
                    [
                        f"대용량 분기 저장: {shorten_url(source_url)}",
                        "북마크: 링크 저장 완료",
                        f"HTML: {fallback_public_url}",
                    ]
                ),
                0,
            )

            response_payload = {
                "status": "fallback_saved",
                "url": source_url,
                "fallbackUrl": fallback_public_url,
                "assetSizeBytes": file_size,
                "maxAssetSizeBytes": MAX_ASSET_SIZE_BYTES,
            }
            self.respond_json(201, response_payload)
        except Exception as exc:  # noqa: BLE001
            log(f"bridge handler error: {exc}")
            self.respond_json(500, {"error": "internal server error"})
        finally:
            if temp_path:
                try:
                    os.unlink(temp_path)
                except OSError:
                    pass


def main() -> None:
    os.makedirs(FALLBACK_DIR, exist_ok=True)
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), SingleFileBridgeHandler)
    log(
        f"karakeep-singlefile-bridge listening on {LISTEN_HOST}:{LISTEN_PORT} "
        f"(max={MAX_ASSET_SIZE_MB}MB, fallback={FALLBACK_DIR})"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
