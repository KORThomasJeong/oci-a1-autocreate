#!/usr/bin/env bash
# ===========================================================================
#  최초 1회 셋업: SSH 키 생성 -> .env 준비 -> terraform init/validate/plan
# ===========================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [1/4] SSH 키페어 생성"
mkdir -p keys
if [ ! -f keys/oci_instance ]; then
  ssh-keygen -t ed25519 -N "" -f keys/oci_instance -C "oci-a1-auto" >/dev/null
  echo "    생성됨: keys/oci_instance (.pub)"
else
  echo "    이미 존재 - 건너뜀"
fi
chmod 600 keys/oci_instance

echo "==> [2/4] .env 준비"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "    .env 생성됨 -> 텔레그램 토큰/chat_id 를 입력하세요!"
else
  echo "    이미 존재 - 건너뜀"
fi

echo "==> [3/4] terraform init & validate"
export TF_VAR_ssh_public_key_path="$SCRIPT_DIR/keys/oci_instance.pub"
cd terraform
terraform init -input=false
terraform validate

echo "==> [4/4] terraform plan (미리보기, 실제 생성 안 함)"
terraform plan -input=false || true
cd "$SCRIPT_DIR"

cat <<EOF

==========================================================
 셋업 완료. 다음 단계:
   1) .env 파일에 TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID 입력
   2) ./install-cron.sh   (2분마다 자동 재시도 등록)
 수동 1회 테스트:        ./retry.sh
 상태 확인:              ./status.sh
 중지:                   ./stop.sh
==========================================================
EOF
