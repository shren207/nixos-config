# Host Handling

## `--hosts` 인자 파싱

```python
import argparse

VALID_HOSTS = {"mac", "minipc"}

parser.add_argument(
    "--hosts",
    type=lambda s: [h.strip() for h in s.split(",")],
    default=["mac", "minipc"],
    help="comma-separated host list. choices: mac, minipc"
)

args = parser.parse_args()
for h in args.hosts:
    if h not in VALID_HOSTS:
        parser.error(f"invalid host: {h!r}. valid: {sorted(VALID_HOSTS)}")
```

**whitelist reject-fast 의무**: `{mac, minipc}` 외 값은 즉시 거부. user-controlled 입력이 SSH alias로 들어가는 경계 보호.

## SSH alias 매핑

각 호스트의 SSH alias는 `~/.ssh/config`의 `Host mac` / `Host minipc` 정의에 의존한다. 본 Skill은 alias가 동작한다고 가정한다 (alias 부재 시 SSH 명령이 실패 → partial result).

| 현재 머신 | mac 대상 | minipc 대상 |
|-----------|----------|-------------|
| Mac (Darwin) | local | `ssh minipc` |
| MiniPC (NixOS Linux) | `ssh mac` | local |

현재 머신 판별: `platform.system()`이 `"Darwin"`이면 Mac, `"Linux"`이면 MiniPC (현재 NixOS 호스트는 MiniPC 1대뿐 — 호스트 추가 시 `hostname` 보강 필요).

## SSH 호출 패턴 (subprocess.run 고정 argv)

shell string 금지. 항상 list argv 형태로 subprocess.run 호출.

```python
import subprocess

def remote_glob(alias: str, pattern: str) -> list[str]:
    """원격 호스트에서 jsonl 파일 path glob."""
    if alias not in VALID_HOSTS:
        raise ValueError(f"invalid host: {alias!r}")
    
    # allowlist 패턴: ~/.claude/projects/ 또는 ~/.codex/sessions/
    if not (pattern.startswith("~/.claude/projects/") or pattern.startswith("~/.codex/sessions/")):
        raise ValueError(f"disallowed pattern: {pattern!r}")
    
    # find 명령으로 jsonl path만 수집
    proc = subprocess.run(
        ["ssh", alias, "find", pattern, "-type", "f", "-name", "*.jsonl"],
        capture_output=True, text=True, timeout=60
    )
    if proc.returncode != 0:
        return []  # partial result
    return [p for p in proc.stdout.splitlines() if "/subagents/" not in p]


def remote_cat(alias: str, path: str) -> str:
    """원격 jsonl 파일 내용 가져오기."""
    if alias not in VALID_HOSTS:
        raise ValueError(f"invalid host: {alias!r}")
    if not (path.startswith("/Users/") or path.startswith("/home/")):
        raise ValueError(f"disallowed path: {path!r}")
    
    proc = subprocess.run(
        ["ssh", alias, "cat", path],
        capture_output=True, text=True, timeout=120
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout
```

**금지**:
- `subprocess.run(f"ssh {alias} cat {path}", shell=True)` — 인젝션 위험.
- `os.system(...)` — 인젝션 위험.
- `subprocess.run(["bash", "-c", ...])` — shell 경유.

**허용**:
- `subprocess.run(["ssh", alias, "find", ...], capture_output=True)` — argv 고정.
- `subprocess.run(["ssh", alias, "cat", path], ...)` — argv 고정.

## remote command allowlist

원격 호스트에서 실행 가능한 명령은 다음으로 제한:
- `find <prefix> -type f -name "*.jsonl"` (path glob)
- `cat <path>` (파일 내용 read)
- `stat <path>` (파일 메타 — 선택)

`rm`, `mv`, `mkdir`, `git`, `curl`, `wget` 등은 사용하지 않는다 (read-only 분석 의도).

## partial result 처리

SSH 호출이 실패한 호스트는 측정에서 제외하고 `warnings` 필드에 명시적 경고를 추가한다 (silent fallback 금지).

```python
warnings = []
results = {}
for host in args.hosts:
    try:
        results[host] = collect_host_data(host)
    except subprocess.TimeoutExpired:
        warnings.append(f"host {host}: SSH timeout — partial result")
    except subprocess.CalledProcessError as e:
        warnings.append(f"host {host}: SSH error (rc={e.returncode}) — partial result")
    except FileNotFoundError:
        warnings.append(f"host {host}: ssh binary not found — partial result")
```

markdown stdout 출력에는 footer에 warnings 섹션이 추가된다:

```markdown
---
⚠ Warnings:
- host minipc: SSH timeout — partial result
```

JSON sidecar의 `warnings` 배열에도 같은 메시지가 들어간다.

## Mac/MiniPC 경로 매핑

| 호스트 | Claude Code base | Codex base |
|--------|-----------------|------------|
| mac | `/Users/green/.claude/projects/` | `/Users/green/.codex/sessions/` |
| minipc | `/home/greenhead/.claude/projects/` | `/home/greenhead/.codex/sessions/` |

`--corpus manifest.json` 사용 시 path prefix(`/Users/` 또는 `/home/`)로 host 자동 분류.
