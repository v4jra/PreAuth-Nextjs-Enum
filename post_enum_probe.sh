#!/usr/bin/env bash
# post_enum_probe.sh — focused safe probes
set -euo pipefail
TARGET=${1:-}
if [[ -z "$TARGET" ]]; then echo "Usage: $0 https://target"; exit 1; fi
OUT=post_enum_$(date +%Y%m%d_%H%M%S)
mkdir -p "$OUT"
echo "[*] Output -> $OUT"

# robots & sitemap
curl -sS -k "$TARGET/robots.txt" -o "$OUT/robots.txt" || true
curl -sS -k "$TARGET/sitemap.xml" -o "$OUT/sitemap.xml" || true

# openid/oauth discovery
curl -sS -k "$TARGET/.well-known/openid-configuration" -o "$OUT/openid.json" || true
curl -sS -k "$TARGET/.well-known/oauth-authorization-server" -o "$OUT/oauth-discovery.json" || true

# common api HEAD probes
for e in api api/auth api/users api/agents api/upload api/health api/status api/config; do
  echo "HEAD $e" >> "$OUT/api_head.txt"
  curl -sS -I -k "$TARGET/$e" | sed -n '1,16p' >> "$OUT/api_head.txt" || true
done

# CORS quick checks
for p in "/api/" "/api/auth" "/api/users" "/api/agents" "/api/config"; do
  echo "CORS $p" >> "$OUT/cors.txt"
  curl -sS -i -k -H "Origin: https://evil.example" "$TARGET$p" | sed -n '1,30p' >> "$OUT/cors.txt" || true
done

# safe JSON probe redactor: if JSON found, redact long strings
probe_list=("$TARGET/api" "$TARGET/api/auth" "$TARGET/api/users" "$TARGET/api/agents")
for u in "${probe_list[@]}"; do
  echo "GET $u" >> "$OUT/get_probe.txt"
  curl -sS -k "$u" | head -c 200 > "$OUT/get_probe_raw.txt" || true
  # redact obvious tokens (simple)
  sed -E 's/"(access|id|token|secret|api|session)[^"]*":"([^"]{8,})"/"\1":"<REDACTED>"/Ig' "$OUT/get_probe_raw.txt" > "$OUT/get_probe.txt" || true
done

# conservative ffuf (size-diff)
BASELINE=$(curl -sS -k "$TARGET/thispagedoesnotexist" | wc -c)
ffuf -w /usr/share/wordlists/dirb/common.txt -u "$TARGET/FUZZ" -t 20 -mc all -fs "$BASELINE" -o "$OUT/ffuf.json" -of json || true
jq '.results[] | {url:.url,status:.status,length:.length}' "$OUT/ffuf.json" | sed -n '1,200p' > "$OUT/ffuf_filtered.txt" || true

echo "[*] Done. Files in: $OUT"
