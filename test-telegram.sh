#!/usr/bin/env bash
# ===========================================================================
#  텔레그램 설정 테스트
#  - .env 의 TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID 로 테스트 메시지를 전송
#  - chat_id 가 비어 있으면 getUpdates 로 후보를 찾아 안내
#  - 사용법: ./test-telegram.sh ["보낼 메시지(선택)"]
# ===========================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- .env 로드 ---
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a; # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"; set +a
else
  echo "❌ .env 가 없습니다. 먼저 ./setup.sh 를 실행하세요."
  exit 1
fi

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT="${TELEGRAM_CHAT_ID:-}"
MSG="${1:-🔔 OCI 자동생성 봇 테스트 메시지입니다. ($(date '+%Y-%m-%d %H:%M:%S'))}"

# --- 토큰 확인 ---
if [ -z "$TOKEN" ]; then
  cat <<'EOF'
❌ TELEGRAM_BOT_TOKEN 이 비어 있습니다.
   1) 텔레그램에서 @BotFather -> /newbot -> 토큰 발급
   2) .env 의 TELEGRAM_BOT_TOKEN="..." 에 입력 후 다시 실행
EOF
  exit 1
fi

# --- 토큰 형식 확인 (봇 토큰은 반드시 "봇ID:비밀문자열" 형태) ---
if [[ ! "$TOKEN" =~ ^[0-9]+:.+ ]]; then
  cat <<EOF
❌ 토큰 형식이 올바르지 않습니다.
   현재 값: "${TOKEN}"  (콜론(:) 뒷부분이 없습니다)
   봇 토큰은 "봇ID:비밀문자열" 형태여야 합니다.
   예) 123456789:AAH9xKp3...(콜론 뒤 35자가량)
   @BotFather 가 보내준 전체 문자열을 그대로 .env 의 TELEGRAM_BOT_TOKEN 에 넣으세요.
EOF
  exit 1
fi

# --- 토큰 유효성(getMe) ---
echo "==> 봇 토큰 확인 (getMe)"
ME="$(curl -sS -m 15 "https://api.telegram.org/bot${TOKEN}/getMe")"
if ! echo "$ME" | grep -q '"ok":true'; then
  echo "❌ 토큰이 유효하지 않습니다. 응답:"
  echo "   $ME"
  exit 1
fi
BOT_NAME="$(echo "$ME" | sed -n 's/.*"username":"\([^"]*\)".*/\1/p')"
echo "   ✅ 봇 확인됨: @${BOT_NAME}"

# --- chat_id 가 없으면 getUpdates 로 후보 안내 ---
if [ -z "$CHAT" ]; then
  echo
  echo "⚠️  TELEGRAM_CHAT_ID 가 비어 있습니다. 후보를 조회합니다 (getUpdates)..."
  echo "    (먼저 텔레그램에서 @${BOT_NAME} 봇에게 아무 메시지나 한 번 보내야 합니다)"
  UPD="$(curl -sS -m 15 "https://api.telegram.org/bot${TOKEN}/getUpdates")"
  FOUND="$(echo "$UPD" | grep -oE '"chat":\{"id":-?[0-9]+' | grep -oE '\-?[0-9]+' | sort -u)"
  if [ -n "$FOUND" ]; then
    echo "    감지된 chat_id 후보:"
    echo "$FOUND" | sed 's/^/      → /'
    echo "    위 값을 .env 의 TELEGRAM_CHAT_ID 에 넣고 다시 실행하세요."
  else
    echo "    감지된 chat_id 가 없습니다. 봇에게 메시지를 보낸 뒤 다시 실행하세요."
    echo "    원본 응답: $UPD"
  fi
  exit 1
fi

# --- 테스트 메시지 전송 ---
echo
echo "==> 테스트 메시지 전송 (chat_id=${CHAT})"
RESP="$(curl -sS -m 20 -X POST \
  "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${CHAT}" \
  -d "parse_mode=HTML" \
  --data-urlencode "text=${MSG}")"

if echo "$RESP" | grep -q '"ok":true'; then
  echo "   ✅ 전송 성공! 텔레그램을 확인하세요."
  echo "   설정 정상 — 인스턴스 생성 성공 시 알림이 정상 발송됩니다."
else
  echo "   ❌ 전송 실패. 응답:"
  echo "   $RESP"
  echo
  echo "   흔한 원인:"
  echo "   - chat_id 오타 / 그룹이면 음수(-) 포함 여부 확인"
  echo "   - 봇과 대화를 시작하지 않음 (봇에게 먼저 메시지 전송 필요)"
  exit 1
fi
