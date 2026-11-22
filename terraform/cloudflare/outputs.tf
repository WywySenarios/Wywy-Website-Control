output "contract" {
  description = "Cloudflare public-host contract keyed by tunnel name."
  value = {
    public_hosts = local.public_hosts
    tunnel_names = sort(keys(local.public_hosts))
  }
}

output "tunnels" {
  description = "Tunnel IDs keyed by tunnel name."
  value = {
    for name, tunnel in cloudflare_zero_trust_tunnel_cloudflared.this :
    name => tunnel.id
  }
}

output "dns_records" {
  description = "DNS record IDs keyed by tunnel name."
  value = {
    for name, record in cloudflare_dns_record.this :
    name => record.id
  }
}
