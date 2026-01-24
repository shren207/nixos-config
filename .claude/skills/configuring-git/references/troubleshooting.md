# 트러블슈팅

Git 관련 문제와 해결 방법을 정리합니다.

## 목차

- [delta가 적용되지 않음](#delta가-적용되지-않음)
- [~/.gitconfig과 Home Manager 설정이 충돌함](#gitconfig과-home-manager-설정이-충돌함)
- [git commit 시 Author identity unknown](#git-commit-시-author-identity-unknown)

---

## delta가 적용되지 않음

**증상**: `programs.delta.enable = true`를 설정했는데 `git diff`에서 delta가 사용되지 않음

**원인**: `enableGitIntegration`이 명시적으로 설정되지 않음. Home Manager 최신 버전에서는 자동 활성화가 deprecated됨.

**진단**:
```bash
# delta 설치 확인
which delta
# 예상: /etc/profiles/per-user/<username>/bin/delta

# git pager 설정 확인
git config --get core.pager
# 비어있으면 문제
```

**해결**: `enableGitIntegration = true` 추가

```nix
# modules/shared/programs/git/default.nix
programs.delta = {
  enable = true;
  enableGitIntegration = true;  # 이 줄이 필수!
  options = {
    navigate = true;
    dark = true;
  };
};
```

> **참고**: `programs.delta`는 `programs.git`과 별도 모듈입니다. 이전에는 `programs.git.delta`였지만, 현재는 분리되었습니다.

---

## ~/.gitconfig과 Home Manager 설정이 충돌함

**증상**: NixOS로 Git 설정을 관리하는데, 수동 설정(`~/.gitconfig`)이 계속 적용됨

**원인**: Git은 여러 설정 파일을 병합하여 사용합니다:

| 우선순위 | 경로 | 설명 |
|---------|------|------|
| 1 | `~/.gitconfig` | 수동 관리 (존재하면 읽음) |
| 2 | `~/.config/git/config` | Home Manager 관리 |
| 3 | `.git/config` | 프로젝트별 로컬 |

Home Manager는 XDG 표준 경로(`~/.config/git/config`)를 사용하므로, `~/.gitconfig`이 있으면 두 설정이 병합됩니다.

**해결**: `~/.gitconfig` 삭제

```bash
# 백업 후 삭제 (권장)
mv ~/.gitconfig ~/.gitconfig.backup

# 또는 바로 삭제
rm ~/.gitconfig
```

**확인**:
```bash
# Home Manager가 관리하는 설정만 표시되어야 함
git config --list --show-origin | grep "\.config/git"
```

---

## git commit 시 Author identity unknown

> **발생 시점**: NixOS 초기 설치 시

**증상**: git commit 실행 시 author 정보 없음 에러.

```
$ git commit -m "message"
Author identity unknown

*** Please tell me who you are.

Run
  git config --global user.email "you@example.com"
  git config --global user.name "Your Name"
```

**원인**: 새로 설치된 환경에서 git user 설정이 없음. Home Manager의 git 모듈이 아직 적용되지 않은 상태.

**해결**: 수동으로 git config 설정

```bash
git config --global user.email "your-email@example.com"
git config --global user.name "your-username"
```

**참고**: Home Manager의 `programs.git` 설정이 적용되면 이 설정은 자동으로 관리됩니다. 하지만 첫 rebuild 전에 commit이 필요한 경우 수동 설정이 필요합니다.
