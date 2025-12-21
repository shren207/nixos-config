#!/bin/bash
# Folder Action: 파일 이름을 타임스탬프로 변경
# 감시 폴더: ~/FolderActions/rename-asset/
# 결과물: ~/Downloads/<타임스탬프>.<확장자>

set -euo pipefail

WATCH_DIR="$HOME/FolderActions/rename-asset"
DEST_DIR="$HOME/Downloads"
LOCK_FILE="/tmp/rename-asset.lock"

# 중복 실행 방지
if [ -f "$LOCK_FILE" ]; then
    exit 0
fi
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# 카운터 (동시에 여러 파일 처리 시)
i=1

# 감시 폴더 내 파일 처리
find "$WATCH_DIR" -type f -maxdepth 1 ! -name ".*" | while read -r f; do
    [ -f "$f" ] || continue

    filename=$(basename "$f")
    ext="${filename##*.}"
    timestamp=$(date +"%Y%m%dT%H%M%S%3N")

    # 새 파일명 생성
    new_filename="${timestamp}_${i}.${ext}"
    output_path="${DEST_DIR}/${new_filename}"

    # 파일 이동
    if mv -- "$f" "$output_path"; then
        echo "[$(date)] 이동 완료: $filename -> $new_filename"
    else
        echo "[$(date)] 이동 실패: $filename" >&2
    fi

    ((i++))
done
