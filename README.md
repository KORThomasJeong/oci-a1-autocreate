# oci-a1-autocreate

OCI 무료 등급 ARM 인스턴스(`VM.Standard.A1.Flex`)는 인기 리전에서
`Out of host capacity` 에러로 생성이 자주 실패합니다.
이 도구는 **cron 으로 2분마다 `terraform apply` 를 재시도**하다가,
용량이 확보되어 **생성에 성공하면 텔레그램으로 알림**을 보내고 스스로 멈춥니다.

> Terraform + OCI Resource Manager 대신 **로컬 Terraform CLI + cron** 조합으로
> 가볍게 무한 재시도하는 것이 핵심입니다.

## 동작 방식

```
cron(2분) ─▶ retry.sh ─▶ terraform apply
                          ├─ 성공            ─▶ 텔레그램 알림 + .succeeded + cron 자동 해제
                          ├─ Out of capacity ─▶ 조용히 종료 (다음 주기에 재시도)
                          └─ 그 외 에러      ─▶ 텔레그램 1회 통지 (스팸 방지)
```

- 네트워크(인터넷 게이트웨이/라우트)는 **최초 1회만** 생성되고, 이후엔 인스턴스만 반복 시도합니다.
- 동시 실행은 `flock` 으로 방지합니다.
- 성공 시 `.succeeded` 플래그를 남기고 자신의 cron 항목을 제거합니다.

## 사전 준비

| 필요 | 설명 |
|---|---|
| Terraform | `terraform -version` (provider `oracle/oci` 자동 설치) |
| OCI CLI 인증 | `~/.oci/config` 의 `DEFAULT` 프로필 (API 키). `oci iam region list` 로 동작 확인 |
| cron | Linux `cron` 데몬 |
| 텔레그램 봇 | @BotFather 토큰 + chat_id |
| 기존 VCN/서브넷 | 공인 IP 허용 서브넷. (게이트웨이는 이 도구가 추가) |

## 빠른 시작

```bash
cd oci-a1-autocreate

# 1) 셋업: SSH 키 생성 + terraform init/validate/plan
./setup.sh

# 2) .env 편집 — 텔레그램 토큰/chat_id + 본인 OCI OCID 입력
nano .env

# 3) 텔레그램 설정 테스트 (메시지가 오는지 확인)
./test-telegram.sh

# 4) 자동 재시도 등록 (2분마다)
./install-cron.sh

# 상태 확인 / 중지
./status.sh
./stop.sh
```

## .env 설정

`setup.sh` 가 `.env.example` → `.env` 로 복사합니다. **`.env` 는 비밀이 들어가므로 git 에 커밋되지 않습니다.**

```bash
# 텔레그램 (필수)
TELEGRAM_BOT_TOKEN="123456:AAH..."   # @BotFather 전체 토큰 (콜론 포함)
TELEGRAM_CHAT_ID="987654321"

# OCI 리소스 (필수) — 본인 계정 값
TF_VAR_compartment_ocid="ocid1.tenancy.oc1..xxxx"
TF_VAR_availability_domain="Xxxx:AP-CHUNCHEON-1-AD-1"
TF_VAR_vcn_id="ocid1.vcn.oc1.<region>.xxxx"
TF_VAR_subnet_id="ocid1.subnet.oc1.<region>.xxxx"

# 인스턴스 사양 (선택)
TF_VAR_ocpus="2"
TF_VAR_memory_in_gbs="12"
TF_VAR_boot_volume_size_in_gbs="50"
TF_VAR_instance_display_name="oci-a1-auto"
# TF_VAR_region="ap-chuncheon-1"   # 비우면 기본값
```

OCID 확인 방법:
```bash
oci iam compartment list
oci iam availability-domain list
oci network vcn list    --compartment-id <컴파트먼트>
oci network subnet list --compartment-id <컴파트먼트> --vcn-id <VCN>
```

## 텔레그램 봇 설정

1. 텔레그램에서 **@BotFather** → `/newbot` → 토큰 발급 → `TELEGRAM_BOT_TOKEN`
   (토큰은 반드시 `봇ID:비밀문자열` 전체 형태)
2. 만든 봇과 대화방을 열고 아무 메시지나 전송
3. `chat_id` 확인:
   ```bash
   curl "https://api.telegram.org/bot<토큰>/getUpdates"
   ```
   응답 JSON 의 `"chat":{"id": ...}` 값이 `TELEGRAM_CHAT_ID`
4. `./test-telegram.sh` 로 검증 (chat_id 가 비어 있으면 후보를 자동 안내)

## 사양 조정

무료 한도 합계는 **4 OCPU / 24GB RAM / 블록스토리지 200GB** 입니다.
`.env` 에서 값을 바꾸면 다음 cron 주기부터 반영됩니다.

> 💡 용량이 계속 안 잡히면 **사양을 낮추면**(예: `TF_VAR_ocpus="1"`, `TF_VAR_memory_in_gbs="6"`)
> 성공 확률이 올라갑니다.

## 생성 후 접속

```bash
ssh -i ./keys/oci_instance ubuntu@<공인IP>
```
공인 IP 는 텔레그램 알림 또는 `./status.sh` 에서 확인할 수 있습니다.

## 모니터링 / 제어

```bash
./status.sh                      # cron 등록상태 · 성공여부 · 최근 로그
tail -f logs/retry.log           # 실시간 로그
./stop.sh                        # 자동 재시도 중지
```

## 정리(삭제)

```bash
./stop.sh
cd terraform && terraform destroy   # 인스턴스 + 추가한 IGW/라우트 제거
```

## ⚠️ 보안 주의

다음 파일들은 **비밀/계정 정보**이며 `.gitignore` 로 커밋이 차단됩니다. 절대 공개 저장소에 올리지 마세요:

- `.env` — 텔레그램 봇 토큰
- `keys/` — SSH 개인키
- `terraform/terraform.tfstate*` — OCID, 공인 IP 등
- `logs/` — 실행 로그

## 파일 구조

```
oci-a1-autocreate/
├── README.md
├── .env.example          # 설정 템플릿 (커밋됨)
├── .env                  # 실제 설정 (git 제외)
├── .gitignore
├── setup.sh              # 최초 셋업 (SSH 키 + terraform init)
├── retry.sh              # cron 이 2분마다 실행하는 재시도 1회
├── test-telegram.sh      # 텔레그램 설정 테스트
├── install-cron.sh       # cron 등록
├── stop.sh               # cron 해제
├── status.sh             # 상태 확인
├── keys/                 # 생성된 SSH 키페어 (git 제외)
├── logs/                 # 실행/terraform 로그 (git 제외)
└── terraform/
    ├── main.tf           # provider + 네트워크(IGW/라우트) + A1.Flex 인스턴스
    ├── variables.tf      # 변수 (OCID 는 .env 의 TF_VAR_* 로 주입)
    └── outputs.tf        # 공인 IP / OCID / 상태
```

## 라이선스

MIT
