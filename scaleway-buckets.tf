resource "scaleway_object_bucket" "cnpg_backups" {
  name   = "homelab-cnpg-backups"
  region = "fr-par"
  tags = {
    managed-by = "opentofu"
    purpose    = "cloudnative-pg-backups"
  }
}

resource "scaleway_object_bucket" "forgejo_backups" {
  name   = "homelab-forgejo-backups"
  region = "fr-par"
  tags = {
    managed-by = "opentofu"
    purpose    = "forgejo-backups"
  }
}
