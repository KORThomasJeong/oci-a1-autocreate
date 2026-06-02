terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }
}

# ~/.oci/config 의 DEFAULT 프로필(API 키)을 그대로 사용
provider "oci" {
  config_file_profile = var.oci_config_profile
  region              = var.region
}

# ---------------------------------------------------------------------------
# 기존 VCN 재사용 (Oracle-Second-VCN)
# ---------------------------------------------------------------------------
data "oci_core_vcn" "this" {
  vcn_id = var.vcn_id
}

# 인터넷 게이트웨이가 없어 외부 SSH 접속이 불가했음 -> 추가
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "auto-igw"
  enabled        = true
}

# 서브넷이 사용하는 기본 라우트테이블(현재 규칙 없음)에 인터넷 경로 추가
resource "oci_core_default_route_table" "default" {
  manage_default_resource_id = data.oci_core_vcn.this.default_route_table_id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# ---------------------------------------------------------------------------
# 최신 Ubuntu 24.04 (aarch64, A1.Flex 호환) 이미지 자동 조회
# ---------------------------------------------------------------------------
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ---------------------------------------------------------------------------
# A1.Flex 인스턴스 (용량 확보 시 생성)
# ---------------------------------------------------------------------------
resource "oci_core_instance" "a1" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_display_name
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
}
