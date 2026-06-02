#!/usr/bin/env bash
# 인스턴스별로 1분마다 retry.sh 를 실행하는 cron 등록 (중복 자동 제거)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/.env" ] && { set -a; source "$SCRIPT_DIR/.env"; set +a; }
INSTANCES="${INSTANCES:-inst1 inst2}"

# 기존 retry.sh 라인 제거 후 인스턴스별 1분 cron 추가
{
  crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/retry.sh" || true
  for w in $INSTANCES; do
    echo "* * * * * $SCRIPT_DIR/retry.sh $w >> $SCRIPT_DIR/logs/cron.log 2>&1"
  done
} | grep -vE '^[[:space:]]*$' | crontab -

echo "등록된 cron:"
crontab -l | grep "retry.sh"
echo
echo "1분마다 인스턴스별($INSTANCES) 재시도 시작. 로그: tail -f $SCRIPT_DIR/logs/retry.log"
