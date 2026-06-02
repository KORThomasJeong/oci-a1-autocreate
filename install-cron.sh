#!/usr/bin/env bash
# 2분마다 retry.sh 를 실행하는 cron 항목 등록 (중복 자동 제거)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CRON_LINE="*/2 * * * * $SCRIPT_DIR/retry.sh >> $SCRIPT_DIR/logs/cron.log 2>&1"

( crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/retry.sh" ; echo "$CRON_LINE" ) | crontab -

echo "등록 완료. 현재 cron:"
crontab -l | grep "retry.sh"
echo
echo "2분마다 자동 재시도가 시작됩니다."
echo "로그: tail -f $SCRIPT_DIR/logs/retry.log"
