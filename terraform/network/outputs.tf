output "internet_gateway_id" {
  value = oci_core_internet_gateway.igw.id
}

output "vcn_id" {
  value = data.oci_core_vcn.this.id
}
