variable "oci_config_profile" {
  type    = string
  default = "DEFAULT"
}

variable "region" {
  type    = string
  default = "ap-chuncheon-1"
}

# .env 의 TF_VAR_* 로 주입
variable "compartment_ocid" {
  type = string
}

variable "vcn_id" {
  type = string
}
