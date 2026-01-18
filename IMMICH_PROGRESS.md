# Google Photos → Immich 마이그레이션 진행 상황

> **최종 업데이트**: 2026-01-18 23:10 KST
> **상태**: 자동 모니터링 실행 중 (백그라운드)

---

## 1. 작업 개요

### 목표
Google Photos의 모든 사진/동영상 데이터를 자체 호스팅 Immich 서버로 마이그레이션

### 환경
| 구분 | 정보 |
|------|------|
| **소스** | MacBook (`~/Downloads/takeout-*.zip`) |
| **대상** | miniPC (NixOS, Intel N100, 16GB RAM) |
| **Immich 서버** | `http://100.79.80.95:2283` (Tailscale VPN) |
| **저장 경로** | `/mnt/data/google-takeout/` (HDD 1.8TB) |
| **Immich 버전** | v2.4.1 |

### 데이터 규모
| 파일 | 크기 | 자산 수 |
|------|------|---------|
| takeout-...-001.zip | 54GB | ~6,637개 |
| takeout-...-002.zip | 54GB | ~4,948개 |
| takeout-...-003.zip | 5.6GB | ~2,262개 |
| **총계** | **114GB** | **~13,800개** |

---

## 2. 사용된 기술/도구

### 핵심 도구
- **immich-go** v0.31.0: Google Takeout zip 직접 처리 및 Immich 업로드
  - 위치: `/mnt/data/google-takeout/immich-go`
  - GitHub: https://github.com/simulot/immich-go

### 파일 전송
- **rsync**: 체크섬 기반 안전한 전송, 중단 시 재개 가능
- **shasum -a 256**: SHA256 체크섬으로 무결성 검증

### 모니터링/알림
- **Pushover**: 모바일 푸시 알림
  - 자격 증명: `/home/greenhead/.config/pushover/credentials`
- **모니터링 스크립트**: `/mnt/data/google-takeout/monitor-and-sync.sh`

### 인프라
- **Podman**: Immich 컨테이너 실행 (immich-server, immich-ml, postgres, redis)
- **Tailscale VPN**: MacBook ↔ miniPC 보안 연결

---

## 3. 완료된 작업

### 3.1 파일 전송 (완료)
```bash
# 체크섬 생성 (MacBook)
shasum -a 256 takeout-*.zip > takeout-checksums.txt

# 파일 전송 (병렬)
rsync -avz --partial --progress takeout-*.zip minipc:/mnt/data/google-takeout/

# 체크섬 검증 (miniPC)
shasum -a 256 -c takeout-checksums.txt  # 모두 OK
```

### 3.2 개별 파일 업로드 (완료)
| 파일 | 업로드 수 | 중복 건너뜀 | 메타데이터 업데이트 | Pending |
|------|----------|------------|-------------------|---------|
| 003 | 1,947개 | - | - | 285개 |
| 001 | 4,772개 | 534개 | 5,308개 | 206개 |
| 002 | 3,630개 | 869개 | 4,500개 | 438개 |

### 3.3 서버 안정화 (완료)
OOM(Out of Memory) 문제 해결:

**원인**: immich-server 메모리 제한 2GB 초과로 OOM killer에 의해 종료됨

**해결 조치**:
1. **메모리 제한 증가**: `modules/nixos/programs/docker/immich.nix` 수정
   ```nix
   # 변경 전
   "--memory=2g"

   # 변경 후
   "--memory=4g"
   "--memory-swap=6g"
   ```

2. **동시 작업 수 감소** (Immich API로 설정):
   | 작업 | 변경 전 | 변경 후 |
   |------|--------|--------|
   | thumbnailGeneration | 3 | 1 |
   | metadataExtraction | 5 | 2 |
   | smartSearch | 2 | 1 |
   | faceDetection | 2 | 1 |

### 3.4 현재 Immich 서버 통계
```json
{
  "photos": 9794,
  "videos": 829,
  "usage": "97GB"
}
```

---

## 4. 현재 상황

### 4.1 Immich 작업 큐 처리 중
```
작업 큐 남은 수: ~11,400개 (약 50% 완료)
예상 남은 시간: 2-3시간
```

### 4.2 자동 모니터링 실행 중
```bash
# 프로세스 확인
ps aux | grep monitor-and-sync

# 로그 확인
tail -f /mnt/data/google-takeout/migration-monitor.log
```

**모니터링 스크립트 동작:**
1. 5분마다 Immich 작업 큐 확인
2. 모든 작업 완료 시 → 전체 zip 재실행 (메타데이터 매칭)
3. 완료 시 Pushover 알림 발송

### 4.3 서버 리소스 상태
| 항목 | 값 | 상태 |
|------|-----|------|
| CPU 부하 | ~10.7 | 🟡 높음 (개선 중) |
| 메모리 | 36% | 🟢 정상 |
| immich-server | 1.6GB / 4GB | 🟢 정상 |
| immich-ml | 1.1GB / 4GB | 🟢 정상 |

---

## 5. 알려진 문제점

### 5.1 미리보기 오류 (이미지를 불러오는 중 오류 발생)
- **원인**: 썸네일 생성 작업이 아직 완료되지 않음
- **해결**: 작업 큐 완료 대기 (자동)

### 5.2 메타데이터 누락 (Pending 자산 ~930개)
- **원인**: Google Takeout이 zip 파일을 분할할 때 사진과 메타데이터 JSON이 다른 zip에 저장됨
- **해결**: 전체 zip을 한 번에 재실행하여 매칭 (모니터링 스크립트가 자동 실행)

### 5.3 ~~OOM으로 인한 서버 다운~~ (해결됨)
- **원인**: immich-server 메모리 제한 2GB 초과
- **해결**: 메모리 4GB로 증가 + 동시 작업 수 감소

---

## 6. 내일 해야 할 일

### 6.1 Pushover 알림 확인
- `[Immich] 마이그레이션 완료!` 알림이 오면 성공

### 6.2 Immich 웹 UI 확인
1. http://100.79.80.95:2283 접속
2. 사진 미리보기가 정상적으로 표시되는지 확인
3. 앨범 구조 확인 (앱개발, React-Native, 투자 등)
4. 메타데이터 확인:
   - 촬영 날짜/시간
   - 위치 정보 (지도에서 확인)
   - 설명(description)

### 6.3 실패한 작업 재시도 (필요 시)
1. 관리자 → Jobs 페이지
2. 실패한 작업이 있으면 "All" 버튼으로 재시도

### 6.4 로그 확인 (문제 발생 시)
```bash
# 모니터링 로그
ssh minipc 'cat /mnt/data/google-takeout/migration-monitor.log'

# Immich 서버 로그
ssh minipc 'sudo podman logs immich-server --tail 100'
ssh minipc 'sudo podman logs immich-ml --tail 100'
```

### 6.5 정리 (모든 검증 완료 후)
```bash
# Takeout 파일 삭제
ssh minipc 'rm -rf /mnt/data/google-takeout'

# API 키 삭제 (Immich 웹 UI → 계정 설정 → API 키)
```

---

## 7. 주요 명령어 참조

### Immich API 테스트
```bash
# 서버 버전 확인
curl -s -H "x-api-key: $API_KEY" http://100.79.80.95:2283/api/server/version

# 통계 확인
curl -s -H "x-api-key: $API_KEY" http://100.79.80.95:2283/api/server/statistics

# 작업 큐 상태
curl -s -H "x-api-key: $API_KEY" http://100.79.80.95:2283/api/jobs
```

### immich-go 명령어
```bash
cd /mnt/data/google-takeout

# dry-run (시뮬레이션)
./immich-go upload from-google-photos \
  --server http://100.79.80.95:2283 \
  --api-key "$API_KEY" \
  --dry-run \
  ./takeout-*.zip

# 실제 업로드
./immich-go upload from-google-photos \
  --server http://100.79.80.95:2283 \
  --api-key "$API_KEY" \
  ./takeout-*.zip
```

### 서비스 관리
```bash
# Immich 컨테이너 상태
ssh minipc 'sudo podman ps | grep immich'

# 컨테이너 리소스 확인
ssh minipc 'sudo podman stats --no-stream'

# NixOS 설정 재적용
ssh minipc 'cd ~/IdeaProjects/nixos-config && git pull && sudo nixos-rebuild switch --flake .'
```

---

## 8. 파일 위치 요약

| 항목 | 경로 |
|------|------|
| Takeout zip 파일 | `/mnt/data/google-takeout/takeout-*.zip` |
| immich-go 바이너리 | `/mnt/data/google-takeout/immich-go` |
| 모니터링 스크립트 | `/mnt/data/google-takeout/monitor-and-sync.sh` |
| 모니터링 로그 | `/mnt/data/google-takeout/migration-monitor.log` |
| 업로드 로그 | `/mnt/data/google-takeout/migration-00X.log` |
| Pushover 자격 증명 | `/home/greenhead/.config/pushover/credentials` |
| Immich 데이터 | `/mnt/data/immich/photos/` |
| Immich NixOS 설정 | `modules/nixos/programs/docker/immich.nix` |

---

## 9. 설정 변경 이력

### 2026-01-18 23:05 - 서버 안정화
**커밋**: `89182a3 feat(docker): Immich 서비스 활성화 (Phase 2)`
**커밋**: `02968c9 fix(immich): 메모리 제한 2GB→4GB 증가 (OOM 방지)`

**변경 내용**:
1. `modules/nixos/programs/docker/immich.nix`:
   - `--memory=2g` → `--memory=4g`
   - `--memory-swap=6g` 추가

2. Immich API 설정 변경:
   - 동시 작업 수 감소 (CPU 부하 완화)

---

## 10. API 키 정보

> **주의**: 마이그레이션 완료 후 삭제 권장

- **키 이름**: `google-takeout-migration`
- **권한**: 모두 허용
- **생성일**: 2026-01-18

---

## 11. 타임라인

| 시간 | 작업 |
|------|------|
| 19:00 | 마이그레이션 계획 수립 |
| 19:30 | 파일 전송 시작 (병렬) |
| 20:30 | 파일 전송 완료, 체크섬 검증 |
| 20:35 | 파일3 업로드 완료 (1,947개) |
| 21:00 | 파일1 업로드 완료 (4,772개) |
| 21:45 | 파일2 업로드 완료 (3,630개) |
| 22:00 | Immich 작업 큐 상태 분석 |
| 22:15 | 자동 모니터링 스크립트 실행 |
| 22:20 | 서버 다운 감지 (OOM) |
| 22:55 | 원인 분석: 메모리 부족 + CPU 과부하 |
| 23:05 | 메모리 4GB 증가, 동시 작업 수 감소 |
| 23:08 | 모니터링 스크립트 재시작 |
| ~02:00 (예상) | 작업 큐 완료, 전체 zip 재실행 |
| ~04:00 (예상) | 마이그레이션 완료, Pushover 알림 |

---

## 12. 트러블슈팅 가이드

### OOM (Out of Memory) 발생 시
```bash
# 1. OOM 로그 확인
ssh minipc 'sudo dmesg | grep -i oom | tail -10'

# 2. 컨테이너 메모리 사용량 확인
ssh minipc 'sudo podman stats --no-stream'

# 3. 메모리 제한 늘리기 (NixOS 설정 수정 후)
# modules/nixos/programs/docker/immich.nix 수정
ssh minipc 'cd ~/IdeaProjects/nixos-config && sudo nixos-rebuild switch --flake .'
```

### 서버 응답 없음 시
```bash
# 1. 컨테이너 상태 확인
ssh minipc 'sudo podman ps -a | grep immich'

# 2. 서비스 재시작
ssh minipc 'sudo systemctl restart podman-immich-server'

# 3. 로그 확인
ssh minipc 'sudo podman logs immich-server --tail 50'
```

### 모니터링 스크립트 재시작
```bash
# 프로세스 확인
ssh minipc 'ps aux | grep monitor-and-sync | grep -v grep'

# 재시작
ssh minipc 'cd /mnt/data/google-takeout && nohup bash ./monitor-and-sync.sh >> migration-monitor.log 2>&1 &'
```
