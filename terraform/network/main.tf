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

# 재사용할 기존 VCN
data "oci_core_vcn" "this" {
  vcn_id = var.vcn_id
}

# 외부 접속용 인터넷 게이트웨이 (기존 VCN 에 없어서 추가)
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "auto-igw"
  enabled        = true
}

# 기본 라우트테이블에 0.0.0.0/0 -> IGW
resource "oci_core_default_route_table" "default" {
  manage_default_resource_id = data.oci_core_vcn.this.default_route_table_id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}
