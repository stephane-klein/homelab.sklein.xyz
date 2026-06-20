resource "scaleway_object_bucket" "cnpg_backups" {
  name   = "homelab-cnpg-backups"
  region = "fr-par"
  tags = {
    managed-by = "opentofu"
    purpose    = "cloudnative-pg-backups"
  }
}
