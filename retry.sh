#!/usr/bin/env bash
# ===========================================================================
#  OCI A1.Flex 인스턴스 자동 생성 - 재시도 1회 (cron 이 2분마다 실행)
#
#  - 'Out of host capacity' 이면 조용히 종료 -> 다음 cron 주기에 재시도
#  - 성공하면 텔레그램 알림 + cron 자동 해제(.succeeded 플래그)
#  - 용량 외 실제 에러는 텔레그램으로 1회만 통지
#  - 네트워크(IGW/라우트)는 최초 1회만 생성, 이후엔 인스턴스만 재시도
# ===========================================================================
set -uo pipefail

# --- cron 환경 대비: 절대경로/HOME/PATH 고정 ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOME="${HOME:-/home/ubuntu}"
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/bin:$PATH"

TF_DIR="$SCRIPT_DIR/terraform"
LOG_DIR="$SCRIPT_DIR/logs"
TF_LOG="$LOG_DIR/terraform_output.log"
RUN_LOG="$LOG_DIR/retry.log"
SUCCESS_FLAG="$SCRIPT_DIR/.succeeded"
ERROR_FLAG="$SCRIPT_DIR/.error_notified"
mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$RUN_LOG"; }

# --- .env 로드 (KEY=value 들을 자동 export) ---
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a; # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"; set +a
fi

# SSH 공개키 경로는 항상 스크립트 기준 절대경로로 주입
export TF_VAR_ssh_public_key_path="$SCRIPT_DIR/keys/oci_instance.pub"

# --- 텔레그램 전송 ---
send_telegram() {
  local text="$1"
  if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    log "텔레그램 미설정(.env) - 알림 생략"
    return 0
  fi
  if curl -sS -m 20 -o /dev/null -X POST \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "parse_mode=HTML" \
      --data-urlencode "text=${text}"; then
    log "텔레그램 전송 완료"
  else
    log "텔레그램 전송 실패"
  fi
}

# --- 이미 성공했으면 아무것도 하지 않음 ---
if [ -f "$SUCCESS_FLAG" ]; then
  exit 0
fi

# --- 중복 실행 방지(이전 apply 진행 중이면 건너뜀) ---
exec 9>"$SCRIPT_DIR/.lock"
if ! flock -n 9; then
  log "이전 실행 진행 중 - 이번 주기 건너뜀"
  exit 0
fi

cd "$TF_DIR" || { log "terraform 디렉터리 없음: $TF_DIR"; exit 1; }

# init 안 되어 있으면 1회 init (cron 안전장치)
if [ ! -d ".terraform" ]; then
  log "terraform init (최초 1회)"
  terraform init -input=false >> "$TF_LOG" 2>&1
fi

log "terraform apply 시도..."
terraform apply -auto-approve -input=false -no-color > "$TF_LOG" 2>&1
CODE=$?

if [ "$CODE" -eq 0 ]; then
  IP="$(terraform output -raw instance_public_ip 2>/dev/null)"
  OCID="$(terraform output -raw instance_id 2>/dev/null)"
  log "✅ 인스턴스 생성 성공! IP=$IP"
  send_telegram "✅ <b>OCI A1.Flex 인스턴스 생성 성공!</b>
🌐 Public IP: <code>${IP}</code>
🔑 접속: <code>ssh -i ${SCRIPT_DIR}/keys/oci_instance ubuntu@${IP}</code>
🆔 <code>${OCID}</code>
🕒 $(date '+%Y-%m-%d %H:%M:%S')"
  touch "$SUCCESS_FLAG"
  # cron 자동 해제(더 이상 재시도 안 함)
  ( crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/retry.sh" ) | crontab - 2>/dev/null || true
  log "cron 재시도 항목 제거 - 자동화 종료"
  exit 0
fi

# --- 실패 원인 분석 ---
if grep -qiE "Out of (host )?capacity|Out of capacity for shape" "$TF_LOG"; then
  log "⏳ 용량 부족(Out of capacity) - 다음 주기(2분 후) 재시도"
  exit 0
fi

# 용량 외 실제 에러 -> 1회만 통지(스팸 방지)
log "❌ 용량 문제가 아닌 에러 (logs/terraform_output.log 확인 요망)"
if [ ! -f "$ERROR_FLAG" ]; then
  ERR_TAIL="$(tail -n 15 "$TF_LOG" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
  send_telegram "⚠️ <b>OCI 자동생성 에러</b> (용량 문제 아님)
<pre>${ERR_TAIL}</pre>
설정을 확인하세요. (이 알림은 1회만 발송)"
  touch "$ERROR_FLAG"
fi
exit 0
