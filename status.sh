#!/usr/bin/env bash
# 현재 상태 한눈에 보기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== cron 등록 상태 ==="
crontab -l 2>/dev/null | grep "retry.sh" || echo "(미등록)"

echo
echo "=== 생성 성공 여부 ==="
if [ -f "$SCRIPT_DIR/.succeeded" ]; then
  echo "성공 ✅"
  ( cd "$SCRIPT_DIR/terraform" && terraform output 2>/dev/null )
else
  echo "아직 미생성 (용량 대기 중일 수 있음)"
fi

echo
echo "=== 최근 retry 로그 (마지막 15줄) ==="
tail -n 15 "$SCRIPT_DIR/logs/retry.log" 2>/dev/null || echo "(로그 없음)"
