# MiniPC NixOS 전환 체크리스트

## Phase 2: NixOS 설치 (MiniPC에서) ✅ 완료

### 준비물 체크리스트

- [x] NixOS ISO 다운로드 완료 (`~/Downloads/nixos-minimal-25.11.*.iso`)
- [x] ISO 무결성 검사 (SHA256) 통과
- [x] USB에 ISO 굽기
- [x] nixos-config가 GitHub에 push됨
- [x] Mac SSH 공개키가 `hosts/greenhead-minipc/default.nix`에 포함됨
- [x] git 명령어 자동 nix develop 래핑 훅 추가 (`.claude/scripts/wrap-git-with-nix-develop.sh`)

### USB 굽기 (Mac에서)

```bash
# 1. USB 연결 후 디스크 확인
diskutil list

# 2. USB 디스크 찾기 (보통 /dev/disk2, /dev/disk3 등)
#    "external, physical" 표시된 디스크가 USB입니다
#    용량으로 확인하세요 (16GB, 32GB 등)

# 3. USB 언마운트
diskutil unmountDisk /dev/diskN  # N을 실제 번호로 변경

# 4. ISO 굽기 (주의: 올바른 디스크 번호 사용!)
sudo dd if=~/Downloads/nixos-minimal-25.11.*.iso of=/dev/rdiskN bs=4m status=progress
#          ^-- ISO 파일 경로                      ^-- rdisk 사용 (더 빠름)

# 5. USB 추출
diskutil eject /dev/diskN
```

### 설치 순서 ✅ 완료

1. [x] MiniPC에 USB 연결 및 부팅
2. [x] BIOS에서 USB 부팅 설정 (F2, F12, Del 등)
3. [x] NixOS Live 환경 부팅
4. [x] 네트워크 연결 확인: `ip a && ping google.com`
5. [x] `sudo -i`로 root 전환
6. [x] 디스크 확인: `lsblk -o NAME,SIZE,MODEL,TYPE`
   - nvme0n1 (476.9G) = NixOS 설치 대상
   - sda (1.8T) = HDD 보존!
7. [x] disko 설정 다운로드 및 확인
8. [x] disko 실행 (NVMe 포맷)
9. [x] 마운트 확인: `mount | grep /mnt && lsblk`
10. [x] NixOS 설치
11. [x] 재부팅

---

## Phase 2.5: hardware-configuration.nix 교체 ✅ 완료

### MiniPC에서 (재부팅 후)

1. [x] greenhead 사용자로 로그인
2. [x] 비밀번호 설정 (필요시): `passwd`
3. [x] SSH 키 생성
4. [x] nixos-config 클론
5. [x] hardware-configuration.nix 교체
6. [x] rebuild 적용

---

## Phase 3: 초기 설정 ✅ 완료

### 3.1 Tailscale 인증 (MiniPC에서)

1. [x] `sudo tailscale up`
2. [x] 표시된 URL로 인증
3. [x] IP 확인: `tailscale ip -4` → **100.79.80.95**

### 3.2 SSH 설정 (Mac에서)

1. [x] Mac SSH config에 추가 (`ssh minipc` alias)
2. [x] 접속 테스트: `ssh minipc`

### 3.3 Atuin 동기화 (Mac에서)

1. [x] Atuin key 복사
2. [x] Atuin 로그인 및 동기화

---

## 검증 체크리스트 ✅ 완료

### NixOS 설치 검증

- [x] `uname -a` → Linux greenhead-minipc ...
- [x] `nixos-version` → 25.11
- [x] `ls /mnt/data/` → 기존 HDD 데이터 확인

### 네트워크 검증

- [x] `tailscale status` → connected
- [x] Mac에서 `ssh minipc` 성공

### 개발 환경 검증

- [x] `claude --version` → 설치 확인
- [x] `tmux` → 정상 실행
- [x] `atuin status` → 동기화 상태 확인

---

## Phase 4: 문서 최신화 및 모바일 접속 ✅ 완료

### 문서 최신화

- [x] README.md NixOS 섹션 추가
- [x] FEATURES.md NixOS 특화 섹션 추가
- [x] HOW_TO_EDIT.md NixOS rebuild 명령어 추가

### 모바일 접속 (Termius)

- [ ] Termius에 SSH 키 등록 *(사용자 수동 작업)*
- [ ] MiniPC 호스트 추가 (100.79.80.95) *(사용자 수동 작업)*
- [ ] SSH 접속 테스트 *(사용자 수동 작업)*
- [ ] mosh 테스트 (선택) *(사용자 수동 작업)*

### 기존 기능 테스트 ✅ 모두 통과

| 도구 | 버전 | 상태 |
|------|------|------|
| `claude` | 2.1.11 | ✅ |
| `tmux` | 3.6a | ✅ |
| `atuin` | 18.11.0 | ✅ |
| `git` | 2.52.0 | ✅ |
| `lazygit` | 0.58.1 | ✅ |
| `starship` | 1.24.2 | ✅ |
| `zoxide` | 0.9.8 | ✅ |
| `fzf` | 0.67.0 | ✅ |
| `eza` | 0.23.4 | ✅ |
| `bat` | 0.26.1 | ✅ |
| `broot` | 1.54.0 | ✅ |
| `delta` | 0.18.2 | ✅ |
| `ripgrep` | 15.1.0 | ✅ |
| `fd` | 10.3.0 | ✅ |
| `gh` | 2.85.0 | ✅ |
| `mise` | 2026.1.2 | ✅ |

---

## 생성된 스크립트 목록

| 스크립트 | 위치 | 용도 |
|----------|------|------|
| install-minipc.sh | scripts/ | MiniPC에서 NixOS 설치 (참조용) |
| post-install-minipc.sh | scripts/ | 설치 후 설정 (Phase 2.5 + 3) |
| setup-minipc-ssh.sh | scripts/ | Mac에서 SSH 설정 |

---

## 중요 경고

```
⚠️  HDD 보존 확인!
    - NVMe (/dev/nvme0n1) → 포맷됨
    - HDD (/dev/sda) → 보존! (295GB media 데이터)

    disko 실행 전 반드시 lsblk로 확인하세요!
```

---

## 참조 문서

- 상세 계획: `docs/MINIPC_PLAN_V3.md`
- NixOS Manual: https://nixos.org/manual/nixos/stable/
- disko: https://github.com/nix-community/disko
