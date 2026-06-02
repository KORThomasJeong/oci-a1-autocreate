variable "oci_config_profile" {
  type    = string
  default = "DEFAULT"
}

variable "region" {
  type    = string
  default = "ap-chuncheon-1"
}

# 아래 값들은 .env 의 TF_VAR_* 로 주입
variable "compartment_ocid" {
  type = string
}

variable "availability_domain" {
  type = string
}

variable "subnet_id" {
  type = string
}

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

variable "ssh_public_key_path" {
  type = string
}
