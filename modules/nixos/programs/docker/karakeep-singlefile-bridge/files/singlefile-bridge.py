#!/usr/bin/env python3
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


def extract_boundary(content_type: str) -> str | None:
    match = re.search(r'boundary="?([^";]+)"?', content_type, flags=re.IGNORECASE)
    if not match:
        return None
    return match.group(1)


def parse_content_disposition(value: str) -> dict[str, str]:
    parts = [part.strip() for part in value.split(";")]
    attrs: dict[str, str] = {}
    if parts:
        attrs["type"] = parts[0].lower()
    for part in parts[1:]:
        if "=" not in part:
            continue
        key, raw = part.split("=", 1)
        attrs[key.strip().lower()] = raw.strip().strip('"')
    return attrs


def parse_multipart_body(body: bytes, boundary: str) -> tuple[list[tuple[str, str]], dict | None]:
    delimiter = f"--{boundary}".encode("utf-8")
    text_fields: list[tuple[str, str]] = []
    file_part = None

    for chunk in body.split(delimiter):
        if not chunk:
            continue
        if chunk.startswith(b"--"):
            continue
        if chunk.startswith(b"\r\n"):
            chunk = chunk[2:]
        if chunk.endswith(b"\r\n"):
            chunk = chunk[:-2]
        if not chunk or b"\r\n\r\n" not in chunk:
            continue

        header_blob, content = chunk.split(b"\r\n\r\n", 1)
        headers = {}
        for raw_line in header_blob.split(b"\r\n"):
            if b":" not in raw_line:
                continue
            key, value = raw_line.split(b":", 1)
            headers[key.decode("latin1").strip().lower()] = value.decode("latin1").strip()

        disposition = parse_content_disposition(headers.get("content-disposition", ""))
        if disposition.get("type") != "form-data":
            continue

        field_name = disposition.get("name", "")
        if not field_name:
            continue

        filename = disposition.get("filename")
        if filename is not None:
            file_part = {
                "name": field_name,
                "filename": filename,
                "content": content,
                "content_type": headers.get("content-type", "application/octet-stream"),
            }
            continue

        text_fields.append((field_name, content.decode("utf-8", errors="replace")))

    return text_fields, file_part


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

        content_type = self.headers.get("Content-Type", "")
        if not content_type.lower().startswith("multipart/form-data"):
            self.respond_json(415, {"error": "Content-Type must be multipart/form-data"})
            return
        boundary = extract_boundary(content_type)
        if not boundary:
            self.respond_json(400, {"error": "Missing multipart boundary"})
            return

        content_length_raw = self.headers.get("Content-Length", "0")
        try:
            content_length = int(content_length_raw)
        except ValueError:
            self.respond_json(400, {"error": "Invalid Content-Length"})
            return
        if content_length <= 0:
            self.respond_json(400, {"error": "Empty request body"})
            return

        temp_path = None
        try:
            request_body = self.rfile.read(content_length)
            if len(request_body) != content_length:
                self.respond_json(400, {"error": "Truncated multipart body"})
                return

            fields, file_part = parse_multipart_body(request_body, boundary)
            request_body = b""

            if file_part is None:
                self.respond_json(400, {"error": "Missing file field"})
                return
            if file_part.get("name") not in ("file", ""):
                self.respond_json(400, {"error": "Unsupported file field name"})
                return

            source_url = ""
            for key, value in fields:
                if key == "url" and value.strip():
                    source_url = value.strip()
            if not source_url:
                self.respond_json(400, {"error": "Missing url field"})
                return

            original_name = sanitize_filename(str(file_part.get("filename") or "archive.html"))
            file_bytes = file_part.get("content")
            if not isinstance(file_bytes, bytes):
                self.respond_json(400, {"error": "Invalid file payload"})
                return
            suffix = os.path.splitext(original_name)[1] or ".html"
            with tempfile.NamedTemporaryFile(
                delete=False, prefix="karakeep-singlefile-", suffix=suffix
            ) as temp_file:
                temp_path = temp_file.name
                temp_file.write(file_bytes)

            file_size = len(file_bytes)

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
