output "setup_key_nuc_i3_gen5" {
  value       = netbird_setup_key.nuc_i3_gen5.key
  sensitive   = true
  description = "Netbird setup key for nuc-i3-gen5 ISO builds"
}

output "setup_key_nuc_i7_gen11" {
  value       = netbird_setup_key.nuc_i7_gen11.key
  sensitive   = true
  description = "Netbird setup key for nuc-i7-gen11 ISO builds"
}

output "cnpg_backups_bucket_name" {
  value       = scaleway_object_bucket.cnpg_backups.name
  description = "Object Storage bucket for CNPG backups"
}

output "setup_key_dummy1" {
  value       = netbird_setup_key.dummy1.key
  sensitive   = true
  description = "Netbird setup key for dummy1"
}


