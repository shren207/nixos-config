# MiniPC NixOS 전환 체크리스트

## Phase 2: NixOS 설치 (MiniPC에서)

### 준비물 체크리스트

- [x] NixOS ISO 다운로드 완료 (`~/Downloads/latest-nixos-minimal-x86_64-linux.iso`)
- [ ] USB에 ISO 굽기 (아래 명령어 참조)
- [x] nixos-config가 GitHub에 push됨 (commit: 4fd4a28)
- [x] Mac SSH 공개키가 `hosts/greenhead-minipc/default.nix`에 포함됨

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
sudo dd if=~/Downloads/latest-nixos-minimal-x86_64-linux.iso of=/dev/rdiskN bs=4m status=progress
#          ^-- ISO 파일 경로                                   ^-- rdisk 사용 (더 빠름)

# 5. USB 추출
diskutil eject /dev/diskN
```

### 설치 순서

1. [ ] MiniPC에 USB 연결 및 부팅
2. [ ] BIOS에서 USB 부팅 설정 (F2, F12, Del 등)
3. [ ] NixOS Live 환경 부팅
4. [ ] 네트워크 연결 확인: `ip a && ping google.com`
5. [ ] `sudo -i`로 root 전환
6. [ ] 디스크 확인: `lsblk -o NAME,SIZE,MODEL,TYPE`
   - nvme0n1 (476.9G) = NixOS 설치 대상
   - sda (1.8T) = HDD 보존!
7. [ ] disko 설정 다운로드 및 확인
   ```bash
   curl -o /tmp/disko.nix https://raw.githubusercontent.com/shren207/nixos-config/main/hosts/greenhead-minipc/disko.nix
   cat /tmp/disko.nix | grep "device ="
   ```
8. [ ] disko 실행 (NVMe 포맷)
   ```bash
   nix --experimental-features "nix-command flakes" run \
     github:nix-community/disko -- \
     --mode disko /tmp/disko.nix
   ```
9. [ ] 마운트 확인: `mount | grep /mnt && lsblk`
10. [ ] NixOS 설치
    ```bash
    nixos-install --flake github:shren207/nixos-config#greenhead-minipc
    ```
11. [ ] 재부팅: `reboot`

---

## Phase 2.5: hardware-configuration.nix 교체

### MiniPC에서 (재부팅 후)

1. [ ] greenhead 사용자로 로그인
2. [ ] 비밀번호 설정 (필요시): `passwd`
3. [ ] SSH 키 생성
   ```bash
   ssh-keygen -t ed25519 -C "greenhead@minipc"
   cat ~/.ssh/id_ed25519.pub
   # → GitHub에 등록
   ```
4. [ ] nixos-config 클론
   ```bash
   git clone git@github.com:shren207/nixos-config.git ~/nixos-config
   ```
5. [ ] hardware-configuration.nix 교체
   ```bash
   cp /etc/nixos/hardware-configuration.nix ~/nixos-config/hosts/greenhead-minipc/
   cd ~/nixos-config
   git add hosts/greenhead-minipc/hardware-configuration.nix
   git commit -m "feat(minipc): add actual hardware-configuration.nix"
   git push
   ```
6. [ ] rebuild 적용
   ```bash
   sudo nixos-rebuild switch --flake .#greenhead-minipc
   ```

---

## Phase 3: 초기 설정

### 3.1 Tailscale 인증 (MiniPC에서)

1. [ ] `sudo tailscale up`
2. [ ] 표시된 URL로 인증
3. [ ] IP 확인: `tailscale ip -4` → 100.x.x.x

### 3.2 SSH 설정 (Mac에서)

1. [ ] Mac SSH config에 추가
   ```bash
   # 스크립트 사용
   ~/IdeaProjects/nixos-config/scripts/setup-minipc-ssh.sh

   # 또는 수동 추가
   cat >> ~/.ssh/config << 'EOF'
   Host minipc
       HostName 100.x.x.x
       User greenhead
       IdentityFile ~/.ssh/id_ed25519
   EOF
   ```
2. [ ] 접속 테스트: `ssh minipc`

### 3.3 Atuin 동기화 (Mac에서)

```bash
ssh minipc "mkdir -p ~/.local/share/atuin"
scp ~/.local/share/atuin/key minipc:~/.local/share/atuin/

# MiniPC에서
atuin login -u greenhead
atuin sync
```

---

## 검증 체크리스트

### NixOS 설치 검증

- [ ] `uname -a` → Linux greenhead-minipc ...
- [ ] `nixos-version` → 24.11
- [ ] `ls /mnt/data/` → 기존 HDD 데이터 확인

### 네트워크 검증

- [ ] `tailscale status` → connected
- [ ] Mac에서 `ssh minipc` 성공

### 개발 환경 검증

- [ ] `claude --version` → 설치 확인
- [ ] `tmux` → 정상 실행
- [ ] `atuin status` → 동기화 상태 확인

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
