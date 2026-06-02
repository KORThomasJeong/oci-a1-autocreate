terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }
}

provider "oci" {
  config_file_profile = var.oci_config_profile
  region              = var.region
}

# 최신 Ubuntu 24.04 (aarch64, A1.Flex 호환) 이미지
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# 인스턴스 (워크스페이스별로 1대) — 네트워크는 ../network 에서 이미 구성됨
resource "oci_core_instance" "this" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "${var.instance_display_name}-${terraform.workspace}"
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  lifecycle {
    ignore_changes = [
      # 최신 Ubuntu 이미지가 나와도 실행 중 인스턴스를 교체(재생성)하지 않도록 보호
      source_details[0].source_id,
      # NSG/포트는 OCI 콘솔·CLI 로 직접 관리 → terraform 이 떼어내지 않도록 무시
      create_vnic_details[0].nsg_ids,
      # 콘솔에서 인스턴스 이름을 바꿔도 terraform 이 원복하지 않도록 무시
      display_name,
    ]
  }
}
