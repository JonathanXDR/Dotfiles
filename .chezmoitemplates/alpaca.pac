{{- /* Alpaca runs this in otto, so it has to stay ES5. Comments stay template
       comments, which keeps them out of the base64 PAC in the plist.

       An IP address as the host would match the range on every network. An
       invalid network address, leading zeros included, would make isInNet
       match every name that does not resolve, sending traffic to the proxy
       off the corporate network. proxy_network is read with dig, because a
       chezmoi.toml written before the key existed lacks it until the next
       `chezmoi init`. */ -}}
{{- if not (regexMatch `^[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z][a-z0-9-]*$` .proxy_host) -}}
{{-   fail "proxy_host must be a lowercase host name such as proxy.company.com (set it in config.toml, then run chezmoi init)" -}}
{{- end -}}
{{- if not (and (regexMatch `^[0-9]{1,5}$` .proxy_port) (ge (atoi .proxy_port) 1) (le (atoi .proxy_port) 65535)) -}}
{{-   fail "proxy_port must be a port number such as 8080 (set it in config.toml, then run chezmoi init)" -}}
{{- end -}}
{{- $network := dig "proxy_network" "" . -}}
{{- $networkError := "proxy_network must be an IPv4 CIDR range such as 10.20.0.0/16 (set it in config.toml, then run chezmoi init)" -}}
{{- if not (regexMatch `^(0|[1-9][0-9]{0,2})(\.(0|[1-9][0-9]{0,2})){3}/([1-9]|[12][0-9]|3[0-2])$` $network) -}}
{{-   fail $networkError -}}
{{- end -}}
{{- $parts := regexSplit `[./]` $network -1 -}}
{{- range $octet := slice $parts 0 4 -}}
{{-   if gt (atoi $octet) 255 -}}{{ fail $networkError }}{{- end -}}
{{- end -}}
{{- $bits := atoi (index $parts 4) -}}
{{- $mask := list -}}
{{- range $i := until 4 -}}
{{-   $mask = append $mask (index (list 0 128 192 224 240 248 252 254 255) (max 0 (min 8 (sub $bits (mul $i 8))))) -}}
{{- end -}}
function FindProxyForURL(url, host) {
  {{- /* Loopback stays on this machine, also for clients that miss it in
         NO_PROXY */}}
  if (host == "localhost" || dnsDomainIs(host, ".localhost") ||
      shExpMatch(host, "127.*") || host == "::1") {
    return "DIRECT";
  }
  {{- /* The proxy host resolves into the corporate range only on the office
         network or over the VPN. Checking the range, not just the lookup,
         keeps captive portals and wildcard resolvers from getting traffic or
         credentials. Inside the network there is deliberately no direct
         fallback. */}}
  if (isInNet("{{ .proxy_host }}", "{{ join "." (slice $parts 0 4) }}", "{{ join "." $mask }}")) {
    return "PROXY {{ .proxy_host }}:{{ .proxy_port }}";
  }
  return "DIRECT";
}
