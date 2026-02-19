# Hosting Karakeep

## Purpose

Karakeep 웹 아카이버/북마크 관리 서비스 운영 스킬.
`https://archive.greenhead.dev`에서 Tailscale VPN 전용으로 제공.

## Architecture

3컨테이너 Podman 구성 (`karakeep-network`):

| 컨테이너 | 이미지 | 역할 | 리소스 |
|-----------|--------|------|--------|
| `karakeep` | `ghcr.io/karakeep-app/karakeep:release` | Next.js 앱 (포트 3000) | 1.5GB / 1 CPU |
| `karakeep-chrome` | `gcr.io/zenika-hub/alpine-chrome:124` | 헤드리스 Chrome (스크린샷) | 1GB / 1 CPU |
| `karakeep-meilisearch` | `getmeili/meilisearch:v1.13.3` | 전문 검색 | 512MB / 0.5 CPU |

### Data Path

```text
/mnt/data/karakeep/         # HDD (모든 데이터)
├── db.db                   # 메인 SQLite DB
├── queue.db                # 작업 큐 DB
├── assets/                 # 스크린샷, 아카이브 HTML
└── meilisearch/            # 검색 인덱스

/mnt/data/backups/karakeep/ # SQLite 백업 (매일 05:00, 30일 보관)
```

### Key Files

| 파일 | 역할 |
|------|------|
| `modules/nixos/programs/docker/karakeep.nix` | 메인 모듈 (3컨테이너 + 네트워크 + env) |
| `modules/nixos/programs/docker/karakeep-backup.nix` | SQLite 백업 (db.db + queue.db) |
| `modules/nixos/programs/docker/karakeep-notify.nix` | 웹훅→Pushover 브리지 (socat) |
| `modules/nixos/programs/karakeep-update/` | 버전 체크 + 수동 업데이트 |
| `modules/nixos/programs/caddy.nix` | HTTPS 리버스 프록시 (CSP 제거 포함) |

### Secrets (agenix)

| 시크릿 | 용도 |
|--------|------|
| `karakeep-nextauth-secret.age` | JWT 서명 키 (NEXTAUTH_SECRET) |
| `karakeep-meili-master-key.age` | Meilisearch 인증 키 |
| `pushover-karakeep.age` | Pushover 알림 자격증명 |

## SingleFile Integration

브라우저 SingleFile 확장으로 페이지를 Karakeep에 push:

1. SingleFile 확장 → Destinations → "Upload to a REST Form API"
2. URL: `https://archive.greenhead.dev/api/v1/bookmarks/singlefile`
3. Token: Karakeep UI → User Settings → API Keys에서 발급
4. Data field: `file`, URL field: `url`

## Webhook Notification

`karakeep-webhook-bridge.service` (socat TCP:9999):
- Karakeep `WEBHOOK_URL` → `host.containers.internal:9999`
- `crawled` 이벤트만 Pushover로 전달
- `CRAWLER_ALLOWED_INTERNAL_HOSTNAMES` 필수 (v0.30.0+ 내부 IP 차단)

## Backup & Update

- **백업**: `sudo systemctl start karakeep-backup` (매일 05:00 자동)
- **업데이트**: `sudo karakeep-update` (수동), `karakeep-version-check` (매일 06:00 자동)

### Restore

```bash
# 1. 서비스 중지
sudo systemctl stop podman-karakeep.service

# 2. 백업에서 DB 복원
sudo gunzip -k /mnt/data/backups/karakeep/YYYY-MM-DD/db.db.gz
sudo cp /mnt/data/backups/karakeep/YYYY-MM-DD/db.db /mnt/data/karakeep/db.db
sudo gunzip -k /mnt/data/backups/karakeep/YYYY-MM-DD/queue.db.gz
sudo cp /mnt/data/backups/karakeep/YYYY-MM-DD/queue.db /mnt/data/karakeep/queue.db

# 3. 서비스 재시작
sudo systemctl start podman-karakeep.service
```

## Troubleshooting

### CSS 렌더링 깨짐 (아카이브 인라인 뷰)

Karakeep의 CSP 헤더가 iframe 내 CSS를 차단하는 알려진 버그.
Caddy에서 CSP 제거로 해결 (`caddy.nix` — `header -Content-Security-Policy`).
Tailscale VPN 전용이므로 XSS 위험 무시 가능.
ref: https://github.com/karakeep-app/karakeep/issues/1977

### 웹훅 전달 실패

v0.30.0+에서 내부 IP 웹훅 기본 차단.
`CRAWLER_ALLOWED_INTERNAL_HOSTNAMES=host.containers.internal` 확인.
```bash
journalctl -u karakeep-webhook-bridge -f
```

### 컨테이너 OOM

리소스 제한: `libraries/constants.nix` → `constants.containers.karakeep`
```bash
podman stats --no-stream karakeep karakeep-chrome karakeep-meilisearch
```

### 모바일 앱 (iOS/Android)

- App Store: "Karakeep" 검색
- 서버 URL: `https://archive.greenhead.dev`
- 인라인 아카이브 뷰에서 CSS 깨짐은 웹과 동일 (CSP 제거로 해결)
