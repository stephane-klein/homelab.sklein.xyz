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
