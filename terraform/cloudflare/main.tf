locals {
  environment = yamldecode(
    file("${path.module}/env/${var.environment}/cloudflare.yaml")
  )
  public_hosts = local.environment.public_hosts
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  for_each = local.public_hosts

  account_id = var.account_id
  name       = each.key
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  for_each = local.public_hosts

  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this[each.key].id

  config = {
    ingress = [
      {
        hostname = each.value.hostname
        service  = each.value.service
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

resource "cloudflare_dns_record" "this" {
  for_each = local.public_hosts

  zone_id = var.zone_id
  name    = each.value.hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this[each.key].id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
