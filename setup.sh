#!/usr/bin/env bash
# ===========================================================================
#  최초 1회 셋업: SSH 키 + .env + terraform init(network/instance) + 워크스페이스
# ===========================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [1/4] SSH 키페어"
mkdir -p keys
[ -f keys/oci_instance ] || ssh-keygen -t ed25519 -N "" -f keys/oci_instance -C "oci-a1-auto" >/dev/null
chmod 600 keys/oci_instance
echo "    keys/oci_instance(.pub)"

echo "==> [2/4] .env"
if [ ! -f .env ]; then cp .env.example .env; echo "    .env 생성됨 — 값을 채우세요!"; else echo "    이미 존재"; fi

set -a; source .env; set +a
export TF_VAR_ssh_public_key_path="$SCRIPT_DIR/keys/oci_instance.pub"
INSTANCES="${INSTANCES:-inst1 inst2}"

echo "==> [3/4] network init/validate"
( cd terraform/network && terraform init -input=false >/dev/null && terraform validate )

echo "==> [4/4] instance init + 워크스페이스 ($INSTANCES)"
cd terraform/instance
terraform init -input=false >/dev/null
terraform validate
for w in $INSTANCES; do
  terraform workspace list | tr -d ' *' | grep -qx "$w" || terraform workspace new "$w" >/dev/null
done
terraform workspace list
cd "$SCRIPT_DIR"

cat <<EOF

==========================================================
 셋업 완료. 다음 단계:
   1) .env 에 TELEGRAM_*, OCI OCID 값 입력
   2) ./test-telegram.sh     # 텔레그램 설정 확인
   3) ./apply-network.sh     # 공유 네트워크(IGW/라우트) 1회 생성
   4) ./install-cron.sh      # 인스턴스별 1분 재시도 등록 ($INSTANCES)
 상태: ./status.sh   |   중지: ./stop.sh
==========================================================
EOF
