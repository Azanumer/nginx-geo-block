# Nginx GeoIP Country Block

Block whole countries at the edge with Nginx's GeoIP2 module — before PHP,
WordPress or any app code runs. Useful for sites that only serve one region
and keep getting brute-force / spam traffic from elsewhere.

## Files

| File | Purpose |
|---|---|
| `nginx-geo-block.conf` | Copy-paste snippets: `geoip2` database + `map` for `http{}`, and the `return 451` guard for `server{}` |
| `blocked-countries.conf` | The map body — ISO country codes mapped to `1` (blocked). Edit to your list |
| `setup-geoip.sh` | Installs `libnginx-mod-http-geoip2` and downloads GeoLite2-Country |

## Setup

```bash
# 1. Free MaxMind account + license key: https://www.maxmind.com/en/geolite2/signup
sudo ./setup-geoip.sh --license-key YOUR_KEY --reload

# 2. Copy the snippets from nginx-geo-block.conf into your config:
#    geoip2 + map go in http{}, the if-guard goes in server{}.
# 3. Copy blocked-countries.conf to /etc/nginx/ and edit the country list.
sudo cp blocked-countries.conf /etc/nginx/
sudo nginx -t && sudo systemctl reload nginx
```

## Notes

- Blocked visitors get **HTTP 451** ("Unavailable For Legal Reasons") — the
  honest status for a geo-block, distinct from a 403.
- Visitors whose country can't be determined (missing/incomplete DB entry)
  map to `0` (allowed) — fail-open, so a database problem never takes the
  site down for everyone.
- If you use Cloudflare, set `geoip2` to read from the real visitor IP
  (`set_real_ip_from` for Cloudflare ranges) or the block will key off
  Cloudflare's edge IPs instead of the visitor's country.
- GeoLite2 databases are updated weekly by MaxMind; re-run the download
  step (or cron it) to stay current.

## License

MIT — see [LICENSE](LICENSE).
