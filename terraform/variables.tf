# ~/.oci/config 프로필 이름
variable "oci_config_profile" {
  type    = string
  default = "DEFAULT"
}

variable "region" {
  type    = string
  default = "ap-chuncheon-1"
}

# 아래 OCID 들은 .env 의 TF_VAR_* 로 주입 (계정별 값, 코드에 하드코딩하지 않음)

# 컴파트먼트 (보통 루트 테넌시 OCID)
variable "compartment_ocid" {
  type = string
}

# 가용성 도메인 (예: "WZid:AP-CHUNCHEON-1-AD-1")
variable "availability_domain" {
  type = string
}

# 재사용할 기존 VCN / 서브넷
variable "vcn_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

# ---- 인스턴스 사양 (무료 한도: 합계 4 OCPU / 24GB) ----
variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  type    = number
  default = 2
}

variable "memory_in_gbs" {
  type    = number
  default = 12
}

variable "boot_volume_size_in_gbs" {
  type    = number
  default = 50
}

variable "instance_display_name" {
  type    = string
  default = "oci-a1-auto"
}

# SSH 공개키 경로 (retry.sh / setup.sh 가 TF_VAR_ssh_public_key_path 로 절대경로 주입)
variable "ssh_public_key_path" {
  type    = string
  default = ""
}
