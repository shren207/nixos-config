#!/bin/bash
# Folder Action: RAR 압축 + 체크섬 가이드 생성
# 감시 폴더: ~/FolderActions/compress-rar/
# 결과물: ~/Downloads/<파일명>/<파일명>.rar + 데이터_무결성_검증방법.txt

set -euo pipefail

WATCH_DIR="$HOME/FolderActions/compress-rar"
DEST_ROOT="$HOME/Downloads"
LOCK_FILE="/tmp/compress-rar.lock"

# 중복 실행 방지
if [ -f "$LOCK_FILE" ]; then
    exit 0
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# PATH 설정 (rar 명령어 위치)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# 감시 폴더 내 파일 처리
find "$WATCH_DIR" -type f -maxdepth 1 ! -name ".*" | while read -r f; do
    [ -f "$f" ] || continue

    filename=$(basename "$f")
    name_no_ext="${filename%.*}"

    # 결과 폴더 생성
    target_dir="${DEST_ROOT}/${name_no_ext}"
    mkdir -p "$target_dir"

    # RAR 압축
    rar_output_path="${target_dir}/${name_no_ext}.rar"
    if rar a -rr10% -ma5 -ep1 -idq "$rar_output_path" "$f"; then
        # 체크섬 계산
        checksum_val=$(shasum -a 256 "$rar_output_path" | awk '{print $1}')

        # 품질보증서 생성
        guide_file="${target_dir}/데이터_무결성_검증방법.txt"
        cat <<EOF > "$guide_file"
[데이터 품질 보증서]

파일명: ${name_no_ext}.rar
생성일: $(date "+%Y-%m-%d %H:%M:%S")
SHA-256 Checksum:
${checksum_val}

================================================================
## 데이터 무결성 검증 가이드

이 파일은 원본 데이터의 변조나 손상을 확인하기 위한 인증서입니다.
아래의 명령어를 사용하여 위 Checksum과 일치하는지 확인하세요.

### 1. macOS / Linux (터미널)
터미널을 열고 압축 파일이 있는 폴더로 이동한 뒤 입력:
$ shasum -a 256 "${name_no_ext}.rar"

### 2. Windows (PowerShell)
파워셸을 열고 압축 파일이 있는 폴더로 이동한 뒤 입력:
> Get-FileHash "${name_no_ext}.rar" -Algorithm SHA256

----------------------------------------------------------------
※ 만약 출력된 코드가 위 Checksum과 단 한 글자라도 다르다면,
   파일이 손상된 것이므로 복구(RAR Recovery)를 시도하거나 백업을 다시 받으세요.
================================================================
EOF

        # 원본 삭제
        rm -rf "$f"
        echo "[$(date)] 압축 완료: $filename -> ${target_dir}/"
    else
        echo "[$(date)] 압축 실패: $filename" >&2
    fi
done
