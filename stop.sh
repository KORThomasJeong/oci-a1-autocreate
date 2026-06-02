#!/usr/bin/env bash
# cron 재시도 항목 제거 (인스턴스/네트워크는 건드리지 않음)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
( crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/retry.sh" ) | crontab - 2>/dev/null || true
echo "cron 자동 재시도를 중지했습니다."
crontab -l 2>/dev/null | grep "retry.sh" || echo "(등록된 항목 없음)"
