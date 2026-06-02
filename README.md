# oci-a1-autocreate

OCI 무료 등급 ARM 인스턴스(`VM.Standard.A1.Flex`)는 인기 리전에서
`Out of host capacity` 에러로 생성이 자주 실패합니다.
이 도구는 **cron 으로 1분마다 `terraform apply` 를 재시도**하다가,
용량이 확보되어 **생성에 성공하면 텔레그램으로 알림**을 보내고 스스로 멈춥니다.
**여러 대를 동시에**(인스턴스별 독립 루프) 노릴 수 있습니다.

- 리전: `ap-chuncheon-1` (춘천) · OS: Ubuntu 24.04 aarch64 (최신 이미지 자동)
- 네트워크: 기존 VCN 재사용 + 인터넷 게이트웨이/라우트 자동 추가
- 인증: `~/.oci/config` 의 `DEFAULT` 프로필 (API 키)

## 동작 방식

```
              ┌─ retry.sh inst1 ─┐
cron(1분) ───▶│  (workspace inst1)│─▶ terraform apply ─┬─ 성공 → 텔레그램 + .succeeded.inst1 + cron 해제
              └───────────────────┘                    ├─ Out of capacity → 다음 주기 재시도
              ┌─ retry.sh inst2 ─┐                      └─ 기타 에러 → 텔레그램 1회 통지
cron(1분) ───▶│  (workspace inst2)│─▶ ...
              └───────────────────┘
```

- 인스턴스마다 **terraform workspace** 로 state 를 분리 → 서로 독립, 동시 실행 안전(`TF_WORKSPACE`).
- 공유 네트워크(IGW/라우트)는 `apply-network.sh` 로 **한 번만** 생성.
- 인스턴스별로 **성공/실패/로그/cron** 이 따로 관리됩니다.

## 사전 준비

| 필요 | 설명 |
|---|---|
| Terraform | `terraform -version` (provider `oracle/oci` 자동 설치) |
| OCI CLI 인증 | `~/.oci/config` 의 `DEFAULT` 프로필. `oci iam region list` 로 확인 |
| cron | Linux `cron` 데몬 |
| 텔레그램 봇 | @BotFather 토큰 + chat_id |
| 기존 VCN/서브넷 | 공인 IP 허용 서브넷 (게이트웨이는 이 도구가 추가) |

## 빠른 시작

```bash
cd oci-a1-autocreate

./setup.sh              # SSH 키 + terraform init + 워크스페이스 생성
nano .env               # 텔레그램/OCI OCID/INSTANCES 입력
./test-telegram.sh      # 텔레그램 동작 확인
./apply-network.sh      # 공유 네트워크(IGW/라우트) 1회 생성
./install-cron.sh       # 인스턴스별 1분 재시도 등록

./status.sh             # 상태 확인
./stop.sh               # 전체 재시도 중지
```

## .env 설정

```bash
# 텔레그램 (필수)
TELEGRAM_BOT_TOKEN="123456789:AAH..."   # @BotFather 전체 토큰(콜론 포함)
TELEGRAM_CHAT_ID="987654321"

# 만들 인스턴스 목록 (워크스페이스 이름) — 각각 독립 루프
INSTANCES="inst1 inst2"

# OCI 리소스 (필수) — 본인 계정 값
TF_VAR_compartment_ocid="ocid1.tenancy.oc1..xxxx"
TF_VAR_availability_domain="Xxxx:AP-CHUNCHEON-1-AD-1"
TF_VAR_vcn_id="ocid1.vcn.oc1.<region>.xxxx"
TF_VAR_subnet_id="ocid1.subnet.oc1.<region>.xxxx"

# 인스턴스 사양 (선택, 무료 한도 합계 4 OCPU / 24GB / 200GB)
TF_VAR_ocpus="2"
TF_VAR_memory_in_gbs="12"
TF_VAR_boot_volume_size_in_gbs="50"
```

OCID 확인:
```bash
oci iam compartment list
oci iam availability-domain list
oci network vcn list    --compartment-id <컴파트먼트>
oci network subnet list --compartment-id <컴파트먼트> --vcn-id <VCN>
```

## 인스턴스 추가/접속

- **더 추가**: `.env` 의 `INSTANCES` 에 이름 추가(예: `"inst1 inst2 inst3"`) → `./setup.sh` → `./install-cron.sh`.
  (무료 한도 합계 4 OCPU / 24GB 를 넘지 않게: 예) 2 OCPU × 2대)
- **접속**: `ssh -i ./keys/oci_instance ubuntu@<공인IP>` (IP 는 텔레그램/`status.sh`)

## 서버별 포트 (NSG)

이 도구는 인스턴스를 **하나의 서브넷**에 만듭니다. 서버마다 다른 포트를 열려면
**NSG(Network Security Group)** 를 인스턴스별로 만들어 붙이세요 — 서브넷을 나눌 필요가 없고
실행 중 인스턴스에 즉시 적용됩니다.

```bash
# NSG 생성 + 인스턴스 VNIC 에 부착
NSG=$(oci network nsg create --compartment-id <COMP> --vcn-id <VCN> \
        --display-name my-nsg --query 'data.id' --raw-output)
VNIC=$(oci compute instance list-vnics --instance-id <INSTANCE> --query 'data[0].id' --raw-output)
oci network vnic update --vnic-id "$VNIC" --nsg-ids "[\"$NSG\"]" --force
# 포트 열기 (예: TCP 443)
oci network nsg rules add --nsg-id "$NSG" --security-rules \
  '[{"direction":"INGRESS","protocol":"6","source":"0.0.0.0/0","sourceType":"CIDR_BLOCK","tcpOptions":{"destinationPortRange":{"min":443,"max":443}}}]'
```

> terraform 은 인스턴스의 `nsg_ids`·`display_name`·이미지(`source_id`) 변경을 무시(`ignore_changes`)하므로,
> NSG/포트·인스턴스 이름은 콘솔·CLI 로 자유롭게 관리해도 다음 apply 에서 원복되지 않습니다.

## 정리(삭제)

```bash
./stop.sh
cd terraform/instance && TF_WORKSPACE=inst2 terraform destroy   # 특정 인스턴스
cd terraform/network  && terraform destroy                      # 네트워크(IGW/라우트)
```

## ⚠️ 보안 주의

다음은 비밀/계정 정보이며 `.gitignore` 로 커밋이 차단됩니다. 공개 저장소에 올리지 마세요:

- `.env` (텔레그램 토큰·OCID) · `keys/` (SSH 개인키)
- `terraform/**/terraform.tfstate*` · `logs/`

## 파일 구조

```
oci-a1-autocreate/
├── README.md  ·  LICENSE  ·  .env.example  ·  .gitignore
├── setup.sh            # 최초 셋업(키/init/워크스페이스)
├── apply-network.sh    # 공유 네트워크 1회 생성
├── retry.sh <name>     # cron 이 인스턴스별로 1분마다 실행하는 재시도
├── install-cron.sh     # 인스턴스별 1분 cron 등록
├── test-telegram.sh    # 텔레그램 설정 테스트
├── stop.sh  ·  status.sh
├── keys/   (SSH 키, git 제외)   ·   logs/  (로그, git 제외)
└── terraform/
    ├── network/        # IGW + 라우트 (공유)
    └── instance/       # 인스턴스 (workspace 당 1대: inst1, inst2, ...)
```

## 라이선스

MIT
