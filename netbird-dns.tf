resource "netbird_dns_zone" "nuc_i7_gen11" {
  name    = "nuc-i7-gen11"
  domain  = "nuc-i7-gen11.homelab.stephane-klein.info"
  enabled = true
}

resource "netbird_dns_record" "k3s_api" {
  zone_id = netbird_dns_zone.nuc_i7_gen11.id
  name    = "k3s.nuc-i7-gen11.homelab.stephane-klein.info"
  type    = "CNAME"
  content = "nuc-i7-gen11.homelab.stephane-klein.info"
  ttl     = 300
}
