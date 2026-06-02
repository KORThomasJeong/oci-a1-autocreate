#!/usr/bin/env bash
# ===========================================================================
#  OCI A1.Flex 인스턴스 자동 생성 재시도 1회 — cron 이 인스턴스별로 실행
#  사용법: retry.sh <인스턴스이름>     예) retry.sh inst1
#
#  - terraform workspace 로 인스턴스별 state 분리 (동시 실행 안전: TF_WORKSPACE)
#  - 'Out of capacity' 면 조용히 종료(다음 주기 재시도)
#  - 성공하면 텔레그램 알림 + 해당 인스턴스 cron 자동 해제(.succeeded.<name>)
#  - 공유 네트워크(IGW/라우트)는 apply-network.sh 로 미리 1회 생성해 둠
# ===========================================================================
set -uo pipefail
NAME="${1:-}"
[ -z "$NAME" ] && { echo "사용법: $0 <인스턴스이름(예: inst1)>"; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOME="${HOME:-/home/ubuntu}"
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/bin:$PATH"

INST_DIR="$SCRIPT_DIR/terraform/instance"
LOG_DIR="$SCRIPT_DIR/logs"
TF_LOG="$LOG_DIR/terraform_${NAME}.log"
RUN_LOG="$LOG_DIR/retry.log"
SUCCESS_FLAG="$SCRIPT_DIR/.succeeded.${NAME}"
ERROR_FLAG="$SCRIPT_DIR/.error_notified.${NAME}"
LOCK="$SCRIPT_DIR/.lock.${NAME}"
mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$NAME] $*" | tee -a "$RUN_LOG"; }

[ -f "$SCRIPT_DIR/.env" ] && { set -a; # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"; set +a; }
export TF_VAR_ssh_public_key_path="$SCRIPT_DIR/keys/oci_instance.pub"
export TF_WORKSPACE="$NAME"   # 워크스페이스를 환경변수로 지정 → 동시 실행 race 없음

send_telegram() {
  local text="$1"
  if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    log "텔레그램 미설정 - 알림 생략"; return 0
  fi
  curl -sS -m 20 -o /dev/null -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=HTML" \
    --data-urlencode "text=${text}" \
    && log "텔레그램 전송 완료" || log "텔레그램 전송 실패"
}

[ -f "$SUCCESS_FLAG" ] && exit 0

exec 9>"$LOCK"
flock -n 9 || { log "이전 실행 진행 중 - 건너뜀"; exit 0; }

cd "$INST_DIR" || { log "instance 디렉터리 없음: $INST_DIR"; exit 1; }
[ ! -d ".terraform" ] && { log "terraform init (최초 1회)"; terraform init -input=false >> "$TF_LOG" 2>&1; }
# 워크스페이스 없으면 생성 (select 대신 new — environment 파일 race 회피)
if ! terraform workspace list 2>/dev/null | tr -d ' *' | grep -qx "$NAME"; then
  terraform workspace new "$NAME" >> "$TF_LOG" 2>&1 || true
fi

log "terraform apply 시도..."
terraform apply -auto-approve -input=false -no-color > "$TF_LOG" 2>&1
CODE=$?

if [ "$CODE" -eq 0 ]; then
  IP="$(terraform output -raw instance_public_ip 2>/dev/null)"
  OCID="$(terraform output -raw instance_id 2>/dev/null)"
  log "✅ 생성 성공! IP=$IP"
  send_telegram "✅ <b>OCI 인스턴스 [$NAME] 생성 성공!</b>
🌐 IP: <code>${IP}</code>
🔑 <code>ssh -i ${SCRIPT_DIR}/keys/oci_instance ubuntu@${IP}</code>
🆔 <code>${OCID}</code>
🕒 $(date '+%Y-%m-%d %H:%M:%S')"
  touch "$SUCCESS_FLAG"
  ( crontab -l 2>/dev/null | grep -vE "retry\.sh ${NAME}( |\$)" ) | crontab - 2>/dev/null || true
  log "cron 항목 제거 ($NAME) - 이 인스턴스 자동화 종료"
  exit 0
fi

if grep -qiE "Out of (host )?capacity|Out of capacity for shape" "$TF_LOG"; then
  log "⏳ 용량 부족(Out of capacity) - 다음 주기 재시도"; exit 0
fi

log "❌ 용량 외 에러 (logs/terraform_${NAME}.log 확인)"
if [ ! -f "$ERROR_FLAG" ]; then
  ERR="$(tail -n 15 "$TF_LOG" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
  send_telegram "⚠️ <b>[$NAME] 자동생성 에러</b> (용량 문제 아님)
<pre>${ERR}</pre>"
  touch "$ERROR_FLAG"
fi
exit 0
