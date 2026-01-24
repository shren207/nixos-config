# immich 설정

MiniPC에서 Docker로 운영되는 immich 사진 관리 서비스 설정입니다.

## 목차

- [개요](#개요)
- [관련 파일](#관련-파일)
- [설정 참고](#설정-참고)

---

`modules/nixos/programs/docker/`에서 관리됩니다.

## 개요

immich는 Google Photos 대안으로 사용되는 셀프호스팅 사진/비디오 관리 플랫폼입니다. MiniPC(greenhead-minipc)에서 Docker Compose로 운영됩니다.

## 관련 파일

| 파일 | 설명 |
|------|------|
| `modules/nixos/programs/docker/default.nix` | Docker 서비스 설정 |
| `modules/nixos/programs/docker/files/` | Docker Compose 파일 |

## 설정 참고

immich 설정 및 트러블슈팅에 대한 상세 내용은 nixos-config 저장소의 다음 문서들을 참고하세요:

- **설치 및 운영**: `docs/MINIPC_PLAN_V3.md`
- **트러블슈팅**: `docs/TROUBLESHOOTING.md`

### 주요 설정 항목

| 항목 | 설명 |
|------|------|
| ML 컨테이너 | CPU 버전 사용 (OOM 방지) |
| Tailscale IP 바인딩 | 부팅 순서 문제 대응 로직 포함 |
| 스토리지 | HDD 마운트 경로 사용 |
