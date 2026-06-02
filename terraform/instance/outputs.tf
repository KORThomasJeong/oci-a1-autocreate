output "instance_public_ip" {
  value = oci_core_instance.this.public_ip
}

output "instance_id" {
  value = oci_core_instance.this.id
}

output "instance_state" {
  value = oci_core_instance.this.state
}

output "image_used" {
  value = data.oci_core_images.ubuntu.images[0].display_name
}
