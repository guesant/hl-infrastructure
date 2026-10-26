package main

import rego.v1

protected_records := {"blog", "blog_www"}
dns_only_github_pages_records := {"blog_site", "curriculum"}

deny contains msg if {
	some name
	some record in input.resource.cloudflare_dns_record[name]
	not record.proxied == true
	not is_dns_only_github_pages_record(name, record)
	msg := sprintf("cloudflare_dns_record.%s must be proxied through Cloudflare", [name])
}

is_dns_only_github_pages_record(name, record) if {
	name in dns_only_github_pages_records
	record.type == "CNAME"
	record.content == "guesant.github.io"
	record.proxied == false
}

deny contains msg if {
	some name in protected_records
	some record in input.resource.cloudflare_dns_record[name]
	not prevents_destroy(record)
	msg := sprintf("cloudflare_dns_record.%s must set lifecycle.prevent_destroy", [name])
}

prevents_destroy(record) if {
	some lifecycle in record.lifecycle
	lifecycle.prevent_destroy == true
}

deny contains msg if {
	some name
	some tunnel in input.resource.cloudflare_zero_trust_tunnel_cloudflared[name]
	not tunnel.config_src == "cloudflare"
	msg := sprintf("cloudflare_zero_trust_tunnel_cloudflared.%s must be remotely managed (config_src = \"cloudflare\")", [name])
}

deny contains msg if {
	some terraform in input.terraform
	some encryption in terraform.encryption
	some kind in {"state", "plan"}
	not enforced(encryption, kind)
	msg := sprintf("terraform.encryption.%s must set enforced = true", [kind])
}

enforced(encryption, kind) if {
	some block in encryption[kind]
	block.enforced == true
}

deny contains msg if {
	some terraform in input.terraform
	some providers in terraform.required_providers
	some name, provider in providers
	not regex.match(`^[0-9]+\.[0-9]+\.[0-9]+$`, provider.version)
	msg := sprintf("provider %s must be pinned to an exact version, got %q", [name, provider.version])
}
