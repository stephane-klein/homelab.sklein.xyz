resource "netbird_dns_zone" "nuc_i7_gen11" {
  name                 = "nuc-i7-gen11"
  domain               = "nuc-i7-gen11.homelab.stephane-klein.info"
  enabled              = true
  enable_search_domain = false
  distribution_groups  = [
    netbird_group.homelab_servers.id,
    netbird_group.user_devices.id,
  ]
}

resource "netbird_dns_record" "k3s_api" {
  zone_id = netbird_dns_zone.nuc_i7_gen11.id
  name    = "k3s.nuc-i7-gen11.homelab.stephane-klein.info"
  type    = "CNAME"
  content = "nuc-i7-gen11.homelab.stephane-klein.info"
  ttl     = 300
}

resource "netbird_dns_zone" "sklein_internal" {
  name                 = "sklein internal"
  domain               = "sklein.internal"
  enabled              = true
  enable_search_domain = false
  distribution_groups  = [
    netbird_group.homelab_servers.id,
    netbird_group.user_devices.id,
  ]
}

resource "netbird_dns_record" "wildcard_ingress" {
  zone_id = netbird_dns_zone.sklein_internal.id
  name    = "*.sklein.internal"
  type    = "CNAME"
  content = "nuc-i7-gen11.homelab.stephane-klein.info"
  ttl     = 300
}
