#!/usr/bin/env python3
# Merge repo template into ~/.codex/config.toml.
#
# Repo-managed keys are re-applied from the template on every activation.
# User-owned sections are preserved across activations:
#   - [projects.*]                        (runtime trust entries)
#   - [mcp_servers.<name>] where <name>   is NOT present in the template
#
# Write is atomic (tempfile + os.replace) so a codex process reading the file
# concurrently sees either the old or new content, never a partial merge.

from __future__ import annotations

import copy
import os
import sys
import tempfile
from pathlib import Path

try:
    import tomlkit
except ImportError:
    print("sync-codex-config: tomlkit module required", file=sys.stderr)
    sys.exit(2)


def load_toml(path: Path):
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return tomlkit.document()
    except OSError as e:
        print(f"sync-codex-config: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(2)
    try:
        return tomlkit.parse(text)
    except Exception as e:
        print(f"sync-codex-config: TOML parse failed for {path}: {e}", file=sys.stderr)
        sys.exit(1)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: sync-codex-config.py <template> <target>", file=sys.stderr)
        return 2

    template_path = Path(sys.argv[1])
    target_path = Path(sys.argv[2])

    template = load_toml(template_path)
    existing = load_toml(target_path)

    user_projects = existing.get("projects", None)
    existing_mcps = existing.get("mcp_servers", {}) or {}
    template_mcps = template.get("mcp_servers", {}) or {}
    user_mcp_keys = [k for k in existing_mcps.keys() if k not in template_mcps]

    result = copy.deepcopy(template)

    if user_projects is not None:
        result["projects"] = user_projects

    if user_mcp_keys:
        if "mcp_servers" not in result:
            result["mcp_servers"] = tomlkit.table()
        for k in user_mcp_keys:
            result["mcp_servers"][k] = existing_mcps[k]

    serialized = tomlkit.dumps(result)

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
        print(f"sync-codex-config: write failed: {e}", file=sys.stderr)
        return 2

    n_projects = len(user_projects) if user_projects is not None else 0
    n_user_mcps = len(user_mcp_keys)
    print(
        f"sync-codex-config: preserved {n_projects} projects entries, "
        f"{n_user_mcps} user mcps",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
