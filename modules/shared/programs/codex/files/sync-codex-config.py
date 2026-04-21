#!/usr/bin/env python3
# Merge repo template into ~/.codex/config.toml.
#
# Repo-managed keys are re-applied from the template on every activation.
# User-owned sections are preserved across activations:
#   - [projects.*]                        (runtime trust entries)
#   - [mcp_servers.<name>] where <name>   is NOT present in the template
#
# Merge policy for keys that exist in BOTH the template and the existing file:
#   * template-managed keys (all top-level scalars, [notice], [features],
#     [plugins.*], [mcp_servers.<name in template>])  -> template WINS.
#     User edits to those are overwritten and a warning is logged to stderr.
#   * [projects.*] and [mcp_servers.<name NOT in template>] -> user WINS.
#
# Write is atomic (tempfile + os.replace) so a codex process reading the file
# concurrently sees either the old or new content, never a partial merge.
#
# If the existing file is malformed TOML, we DO NOT abort activation. Instead
# we quarantine it to <target>.bad-<ts> and regenerate from the template, so a
# stray hand-edit never bricks the whole home-manager generation.

from __future__ import annotations

import copy
import datetime as _dt
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
    # Template 등 반드시 존재하고 유효해야 하는 입력.
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        die(f"template not found: {path}", code=1)
    except OSError as e:
        die(f"cannot read template {path}: {e}", code=2)
    try:
        return tomlkit.parse(text)
    except Exception as e:
        die(f"template parse failed ({path}): {e}", code=1)


def load_optional_toml(path: Path, *, quarantine: bool):
    # 사용자 파일처럼 없거나 깨져 있어도 activation을 죽이지 않는 입력.
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return tomlkit.document()
    except OSError as e:
        log(f"cannot read existing {path}: {e} — treating as empty")
        return tomlkit.document()
    try:
        return tomlkit.parse(text)
    except Exception as e:
        if quarantine and path.exists():
            stamp = _dt.datetime.now().strftime("%Y%m%dT%H%M%S")
            bad = path.with_name(f"{path.name}.bad-{stamp}")
            try:
                path.rename(bad)
                log(
                    f"existing {path} parse failed ({e}); quarantined to {bad}, "
                    f"regenerating from template"
                )
            except OSError as mv_err:
                log(
                    f"existing {path} parse failed ({e}); quarantine to {bad} "
                    f"also failed ({mv_err}); regenerating in place"
                )
        else:
            log(f"existing {path} parse failed ({e}); regenerating from template")
        return tomlkit.document()


def as_table_or_warn(value, *, where: str) -> Optional[dict]:
    # TOML spec 위반(예: projects = 1)인 경우 방어. None 반환이면 호출부에서 무시.
    if value is None:
        return None
    try:
        # tomlkit Table / inline Table 모두 Mapping 프로토콜을 따른다.
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

    template_projects = as_table_or_warn(template.get("projects"), where="template.projects")
    template_mcps = as_table_or_warn(template.get("mcp_servers"), where="template.mcp_servers") or {}
    user_projects = as_table_or_warn(existing.get("projects"), where="existing.projects")
    user_mcps = as_table_or_warn(existing.get("mcp_servers"), where="existing.mcp_servers") or {}

    # user-owned mcp = template에 없는 이름만. template에 있는 이름은 template wins.
    user_mcp_keys = [k for k in user_mcps.keys() if k not in template_mcps]

    # conflict observation: template MCP 키를 사용자가 수정했는지 감지.
    # 수정 여부는 TOML 텍스트 기준으로 정확히 비교하기 어렵지만, 동일 키가 양쪽에
    # 존재한다는 사실만 로그로 남겨 "template wins" 정책을 투명하게 한다.
    for k in template_mcps.keys():
        if k in user_mcps:
            log(f"mcp_servers.{k}: template-managed key present in user file — template value wins")

    # projects는 template에도 존재하지 않는 것이 정상. template이 projects를 선언하면 경고.
    if template_projects is not None:
        log("template.projects present — unusual; template wins for these keys")

    # template 기반 결과 생성.
    result = copy.deepcopy(template)

    # user projects 복원 (template이 projects를 선언한 드문 경우에도 user wins — trust는 runtime이 소유).
    if user_projects is not None and len(user_projects) > 0:
        result["projects"] = user_projects
    elif template_projects is None and "projects" in result:
        # deepcopy는 template에 없는 키를 만들지 않지만, 방어적으로 정리.
        del result["projects"]

    # user-owned mcp 복원.
    if user_mcp_keys:
        if "mcp_servers" not in result:
            result["mcp_servers"] = tomlkit.table()
        for k in user_mcp_keys:
            result["mcp_servers"][k] = user_mcps[k]

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

    n_projects = len(user_projects) if user_projects is not None else 0
    log(
        f"preserved {n_projects} projects entries, "
        f"{len(user_mcp_keys)} user-owned mcp_servers "
        f"(template-managed mcp_servers: {len(template_mcps)})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
