output "instance_public_ip" {
  description = "생성된 인스턴스의 공인 IP"
  value       = oci_core_instance.a1.public_ip
}

output "instance_id" {
  description = "인스턴스 OCID"
  value       = oci_core_instance.a1.id
}

output "instance_state" {
  description = "인스턴스 상태"
  value       = oci_core_instance.a1.state
}

output "image_used" {
  description = "사용된 이미지 이름"
  value       = data.oci_core_images.ubuntu.images[0].display_name
}
