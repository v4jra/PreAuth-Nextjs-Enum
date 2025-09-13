# PreAuth-Nextjs-Enum — Safe pre-auth enumeration for Next.js / Vercel apps

*Short:* A small set of safe, non-destructive scripts I use to enumerate public surfaces of Next.js / Vercel web apps before login.  
Focus: /_next/static assets, /_next/data/<buildId> probes, conservative directory fuzzing (size-diff), and light CORS/headers checks. Useful for reconnaissance during VAPT/bug-bounty when authenticated access is not available.

> *Ethical notice:* These scripts are intended for *authorized security testing only* (your own apps, sanctioned pentests, or bug bounty targets with permission). Do *NOT* use them against systems you do not have explicit permission to test.

---

## What’s included
- prelogin_enum.sh — a one-shot enumerator: downloads root HTML, extracts buildId, fetches sample _next assets, searches JS for API strings, probes common _next/data routes and /api/* HEADs, and runs a conservative ffuf size-diff scan.  
- post_enum_probe.sh — focused probes (robots, openid discovery, small CORS checks, safe JSON redaction, conservative ffuf).  
- Example output folders and sample snippets (how to interpret results).

---

## Why this repo is useful
- *Low-noise:* Designed to avoid DoS and obvious WAF triggers (conservative threads, delays).  
- *Next.js / Vercel aware:* Looks for buildId, _next assets and typical API patterns that Next.js apps expose.  
- *Beginner-friendly:* If you’re starting with web VAPT, copy-paste and run these to get immediate leads you can dig into with Burp/DevTools.  
- *Report-friendly:* Produces small text artifacts you can paste into a Google Doc or bug report.

---

## Quick start (copy & paste)

1. Clone repository:
```bash
git clone https://github.com/v4jra/PreAuth-Nextjs-Enum.git
cd PreAuth-Nextjs-Enum
chmod +x prelogin_enum.sh post_enum_probe.sh
