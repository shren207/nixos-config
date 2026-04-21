#!/usr/bin/env python3
# Merge repo template into ~/.codex/config.toml.
#
# Ownership policy:
#   * Template-owned keys   = every top-level key that appears in the template
#                             PLUS every [mcp_servers.<name>] where <name> is
#                             declared in the template.
#     These are (re-)applied from the template on each activation.
#   * User-owned sections   = everything else in the existing file — any
#                             top-level key NOT in the template, `[projects.*]`,
#                             and every [mcp_servers.<name>] where <name> is
#                             NOT declared in the template.
#     These are preserved verbatim, including unknown tables introduced by
#     future Codex CLI features.
#
# On a same-key conflict template ALWAYS wins for template-owned keys; user
# always wins for user-owned keys. This makes the merge "repo overwrite on its
# own keys, leave everything else alone" — the script does not need to learn
# about new Codex sections just to avoid deleting them.
#
# Write is atomic (tempfile + os.replace) so a codex process reading the file
# concurrently sees either the old or new content, never a partial merge.
#
# If the existing file can be read but is malformed TOML, we quarantine it to
# <target>.bad-<ts> and regenerate from the template — a stray hand-edit must
# not brick the whole home-manager generation. Read-level failures that are
# NOT "file missing" (permission denied, I/O error, invalid UTF-8) DO abort,
# because silently replacing an unreadable file would destroy user trust and
# MCP data.

from __future__ import annotations

import copy
import datetime as _dt
import errno
import os
import sys
import tempfile
from pathlib import Path
from typing import Optional

PREFIX = "sync-codex-config"


def log(msg: str) -> None:
    print(f"{PREFIX}: {msg}", file=sys.stderr)


def die(msg: str, code: int = 2) -> "None":
    log(msg)
    sys.exit(code)


def usage() -> "None":
    die(f"usage: {os.path.basename(sys.argv[0])} <template> <target>", code=2)


try:
    import tomlkit
except ImportError:
    die("tomlkit module required (nix: pkgs.python3Packages.tomlkit)", code=2)


def load_required_toml(path: Path):
    # Template이나 필수 입력: 모든 실패는 hard fail이다.
    try:
        data = path.read_bytes()
    except FileNotFoundError:
        die(f"template not found: {path}", code=1)
    except OSError as e:
        die(f"cannot read template {path}: {e}", code=2)
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as e:
        die(f"template not valid UTF-8 ({path}): {e}", code=1)
    try:
        return tomlkit.parse(text)
    except Exception as e:
        die(f"template parse failed ({path}): {e}", code=1)


def load_optional_toml(path: Path, *, quarantine: bool):
    # 사용자 파일처럼 없거나 깨져 있을 수 있는 입력.
    # - ENOENT (파일 없음)            → empty document (첫 실행)
    # - 기타 OSError (EACCES 등)      → hard fail (데이터 보존)
    # - UnicodeDecodeError / TOML 오류 → quarantine 후 empty document (self-heal)
    try:
        raw = path.read_bytes()
    except FileNotFoundError:
        return tomlkit.document()
    except OSError as e:
        # ENOENT 이외의 읽기 실패는 원본 보존이 우선이라 hard fail.
        if e.errno in (errno.EACCES, errno.EPERM, errno.EIO, errno.EISDIR):
            die(
                f"cannot read existing {path} (errno={e.errno}): {e} — refusing to "
                f"overwrite to avoid data loss. Fix permissions then re-run.",
                code=2,
            )
        die(f"cannot read existing {path}: {e}", code=2)

    def _quarantine(reason: str) -> "tomlkit.TOMLDocument":
        if quarantine and path.exists():
            stamp = _dt.datetime.now().strftime("%Y%m%dT%H%M%S")
            bad = path.with_name(f"{path.name}.bad-{stamp}")
            try:
                path.rename(bad)
                log(
                    f"existing {path} {reason}; quarantined to {bad}, "
                    f"regenerating from template"
                )
            except OSError as mv_err:
                log(
                    f"existing {path} {reason}; quarantine to {bad} "
                    f"also failed ({mv_err}); regenerating in place"
                )
        else:
            log(f"existing {path} {reason}; regenerating from template")
        return tomlkit.document()

    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        return _quarantine(f"not valid UTF-8 ({e})")
    try:
        return tomlkit.parse(text)
    except Exception as e:
        return _quarantine(f"TOML parse failed ({e})")


def as_table_or_warn(value, *, where: str) -> Optional[dict]:
    # TOML spec 위반(예: projects = 1)인 경우 방어. None이면 호출부에서 무시.
    if value is None:
        return None
    try:
        iter(value.keys())  # type: ignore[attr-defined]
        return value  # type: ignore[return-value]
    except Exception:
        log(f"ignoring {where}: expected a table, got {type(value).__name__}")
        return None


def main() -> int:
    if len(sys.argv) != 3:
        usage()

    template_path = Path(sys.argv[1])
    target_path = Path(sys.argv[2])

    template = load_required_toml(template_path)
    existing = load_optional_toml(target_path, quarantine=True)

    # template-owned keys = template에 정의된 top-level 키 전부.
    # mcp_servers의 subkey 중 template에 있는 이름만 template-owned로 취급한다.
    template_mcps = as_table_or_warn(template.get("mcp_servers"), where="template.mcp_servers") or {}
    if template.get("projects") is not None:
        # template이 projects를 선언하면 정책 위반이므로 경고만 남기고 무시.
        # user trust는 오직 runtime mutation이 소유한다.
        log("template.projects present — ignored; [projects.*] is user-owned only")

    # result는 existing의 deep copy에서 시작한다. 즉 "user 소유 섹션은 기본적으로 보존".
    result = copy.deepcopy(existing)

    # template top-level 키를 덮어쓴다. projects는 user-owned이므로 skip.
    template_top_keys: list[str] = []
    for key in list(template.keys()):
        if key == "projects":
            continue
        template_top_keys.append(key)
        if key == "mcp_servers":
            # subkey 단위 merge: template에 있는 이름만 덮어쓰고, 사용자가 추가한
            # 이름은 그대로 둔다.
            existing_mcps = as_table_or_warn(
                result.get("mcp_servers"), where="existing.mcp_servers"
            )
            if existing_mcps is None:
                result["mcp_servers"] = copy.deepcopy(template_mcps)
                continue
            for name in list(template_mcps.keys()):
                if name in existing_mcps:
                    # 사용자가 template-managed MCP 키를 수정했어도 template이 이긴다.
                    # stderr 로그로 투명하게 알린다.
                    log(
                        f"mcp_servers.{name}: template-managed key — overwriting "
                        f"existing user edit (template wins)"
                    )
                result["mcp_servers"][name] = copy.deepcopy(template_mcps[name])
        else:
            if key in result:
                log(
                    f"top-level key '{key}': template-managed — overwriting "
                    f"existing user edit (template wins)"
                )
            result[key] = copy.deepcopy(template[key])

    serialized = tomlkit.dumps(result)

    # atomic write with mode 0600.
    target_path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        dir=str(target_path.parent),
        prefix=".config.toml.",
        suffix=".tmp",
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(serialized)
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, target_path)
    except Exception as e:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        die(f"atomic write failed ({target_path}): {e}", code=2)

    # Summary.
    projects_tbl = as_table_or_warn(existing.get("projects"), where="existing.projects")
    existing_mcps = as_table_or_warn(existing.get("mcp_servers"), where="existing.mcp_servers") or {}
    user_mcp_count = sum(1 for k in existing_mcps.keys() if k not in template_mcps)
    user_top_keys = [
        k for k in existing.keys()
        if k not in template_top_keys and k != "projects" and k != "mcp_servers"
    ]
    log(
        f"preserved {len(projects_tbl) if projects_tbl else 0} projects entries, "
        f"{user_mcp_count} user-owned mcp_servers, "
        f"{len(user_top_keys)} unknown top-level keys "
        f"(template-managed top-level: {len(template_top_keys)})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
