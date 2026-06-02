#!/usr/bin/env bash
# 공유 네트워크(인터넷 게이트웨이 + 라우트)를 1회 생성/갱신. 인스턴스 생성 전에 실행.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/.env" ] && { set -a; source "$SCRIPT_DIR/.env"; set +a; }

cd "$SCRIPT_DIR/terraform/network"
terraform init -input=false >/dev/null
terraform apply -auto-approve -input=false
echo "✅ 네트워크(IGW/라우트) 적용 완료."
