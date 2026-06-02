#!/usr/bin/env bash
# 인스턴스별 상태 한눈에 보기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/.env" ] && { set -a; source "$SCRIPT_DIR/.env"; set +a; }
INSTANCES="${INSTANCES:-inst1 inst2}"
export TF_VAR_ssh_public_key_path="$SCRIPT_DIR/keys/oci_instance.pub"

echo "=== cron 등록 상태 ==="
crontab -l 2>/dev/null | grep "retry.sh" || echo "(미등록)"
echo
for w in $INSTANCES; do
  echo "=== $w ==="
  if [ -f "$SCRIPT_DIR/.succeeded.$w" ]; then
    echo "  성공 ✅"
    ( cd "$SCRIPT_DIR/terraform/instance" && TF_WORKSPACE="$w" terraform output 2>/dev/null | sed 's/^/  /' )
  else
    echo "  미생성 (용량 대기 중일 수 있음)"
  fi
done
echo
echo "=== 최근 재시도 로그 (마지막 12줄) ==="
tail -n 12 "$SCRIPT_DIR/logs/retry.log" 2>/dev/null || echo "(로그 없음)"
