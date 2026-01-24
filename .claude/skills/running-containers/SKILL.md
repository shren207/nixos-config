---
name: running-containers
description: |
  This skill should be used when the user asks about "Podman", "Docker",
  "immich 설정", "사진 백업", "컨테이너 OOM", "ML 컨테이너", "CPU 버전",
  "Tailscale IP 바인딩", "OCI 백엔드", "oci-containers", or encounters
  container runtime issues, immich memory problems, or service binding issues.
---

# 컨테이너 관리 (Podman/immich)

Podman 컨테이너 및 immich 사진 백업 서비스 가이드입니다.

## Known Issues

**OCI 백엔드 명시 필수**
- `virtualisation.oci-containers.backend = "podman";` 반드시 설정
- 누락 시 Docker 백엔드로 fallback되어 에러 발생

**immich ML 컨테이너 OOM**
- GPU 없는 환경에서 기본 ML 컨테이너가 메모리 부족
- 해결: CPU 버전 컨테이너 사용 (`ghcr.io/immich-app/immich-machine-learning:release-cpu`)

**Tailscale IP 바인딩 타이밍**
- 부팅 시 Tailscale IP 할당 전에 서비스 시작하면 바인딩 실패
- 해결: systemd 의존성 또는 IP 할당 대기 로직

## 빠른 참조

### Podman 명령어

```bash
# 컨테이너 목록
podman ps -a

# 로그 확인
podman logs <container-name>

# 컨테이너 재시작
podman restart <container-name>

# systemd 서비스로 관리
systemctl --user status podman-<container-name>
```

### immich 서비스 구성

| 컨테이너 | 용도 |
|----------|------|
| immich-server | 메인 API 서버 |
| immich-machine-learning | ML 처리 (얼굴 인식 등) |
| immich-postgres | PostgreSQL 데이터베이스 |
| immich-redis | Redis 캐시 |

### 주요 설정 파일

| 파일 | 용도 |
|------|------|
| `modules/nixos/programs/docker/default.nix` | Podman/컨테이너 설정 |
| `hosts/greenhead-minipc/default.nix` | 호스트별 컨테이너 설정 |

## 자주 발생하는 문제

1. **OCI 백엔드 미설정**: `backend = "podman"` 누락
2. **ML OOM**: CPU 버전 이미지로 변경
3. **IP 바인딩 실패**: Tailscale 의존성 추가

## 레퍼런스

- 트러블슈팅: [references/troubleshooting.md](references/troubleshooting.md)
- immich 설정: [references/immich-setup.md](references/immich-setup.md)
