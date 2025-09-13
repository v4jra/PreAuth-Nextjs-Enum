#!/usr/bin/env bash
# prelogin_enum.sh — safe pre-login enumeration for Next.js/Vercel sites
# Usage: ./prelogin_enum.sh https://abc.example.com
# WARNING: non-destructive but run only on authorized targets.

set -euo pipefail
TARGET=${1:-}
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 https://target.example"
  exit 1
fi

OUTDIR="enum_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR/js" "$OUTDIR/output"
echo "[*] Output -> $OUTDIR"

# 1) fetch root HTML
echo "[*] Fetching root HTML..."
curl -sS -k "$TARGET" -o "$OUTDIR/root.html"
head -n 60 "$OUTDIR/root.html" > "$OUTDIR/output/root_head.txt"

# 2) get buildId if present
echo "[*] Extracting buildId..."
BUILDID=$(rg -o '"buildId"\s*:\s*"\K[^"]+' "$OUTDIR/root.html" || true)
echo "buildId=$BUILDID" > "$OUTDIR/output/buildid.txt"
echo "buildId: $BUILDID"

# 3) extract _next/static asset paths (relative) and prefix
rg -o '(/_next/static/[^"]+)' "$OUTDIR/root.html" | sort -u > "$OUTDIR/output/assets_rel.txt"
sed "s|^|$TARGET|" "$OUTDIR/output/assets_rel.txt" > "$OUTDIR/output/assets_full.txt"
echo "[*] First assets:"
sed -n '1,12p' "$OUTDIR/output/assets_full.txt"

# 4) download up to first 8 assets (low concurrency)
echo "[*] Downloading sample JS assets..."
i=0
while read -r url && [ $i -lt 8 ]; do
  fname=$(basename "$url")
  curl -sS -k "$url" -o "$OUTDIR/js/$fname" || true
  i=$((i+1))
done < "$OUTDIR/output/assets_full.txt"
echo "[*] downloaded $i assets to $OUTDIR/js"

# 5) search downloaded assets for endpoints/tokens (no secrets displayed)
echo "[*] Searching for interesting patterns in JS..."
rg -n --no-ignore-vcs -S "(?:/api/|/_next/data/|graphql|auth|token|clientId|client_id|apiKey|callback|oauth|signin|logout)" "$OUTDIR/js" | sed -n '1,200p' > "$OUTDIR/output/js_candidates.txt"
echo "[*] js_candidates saved to $OUTDIR/output/js_candidates.txt"
sed -n '1,40p' "$OUTDIR/output/js_candidates.txt"

# 6) probe common _next/data routes (if buildId found)
if [[ -n "$BUILDID" ]]; then
  echo "[*] Probing common _next/data routes..."
  routes=(index login dashboard profile agents settings app home)
  for r in "${routes[@]}"; do
    url="$TARGET/_next/data/${BUILDID}/${r}.json"
    echo "[*] GET $url" >> "$OUTDIR/output/nextdata_probe.txt"
    curl -sS -i -k "$url" | sed -n '1,20p' >> "$OUTDIR/output/nextdata_probe.txt" || true
  done
  echo "[*] nextdata results saved -> $OUTDIR/output/nextdata_probe.txt"
else
  echo "[!] no buildId found; skipping _next/data probes"
fi

# 7) probe common /api endpoints with HEAD (safe)
echo "[*] Probing common /api endpoints (HEAD)..."
for e in "api" "api/auth" "api/users" "api/agents" "api/upload" "api/health" "api/status" "api/config"; do
  echo "[*] HEAD $TARGET/$e" >> "$OUTDIR/output/api_head.txt"
  curl -sS -I -k "$TARGET/$e" | sed -n '1,12p' >> "$OUTDIR/output/api_head.txt" || true
done
echo "[*] api head saved -> $OUTDIR/output/api_head.txt"

# 8) baseline 404 size and ffuf size-diff run (conservative)
echo "[*] Getting baseline missing page size..."
BASELINE=$(curl -sS -k "$TARGET/thispagedoesnotexist" | wc -c)
echo "baseline_size=$BASELINE" > "$OUTDIR/output/baseline.txt"
echo "[*] Running ffuf size-diff (low thread)... this can be slow; ctrl-c to stop"
ffuf -w /usr/share/wordlists/dirb/common.txt -u "$TARGET/FUZZ" -t 20 -mc all -fs "$BASELINE" -o "$OUTDIR/output/ffuf.json" -of json || true
jq '.results[] | {url:.url, status:.status, size:.length}' "$OUTDIR/output/ffuf.json" | sed -n '1,100p' > "$OUTDIR/output/ffuf_filtered.txt" || true

echo "[*] All done. Check directory: $OUTDIR"
