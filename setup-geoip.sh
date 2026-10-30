#!/usr/bin/env bash
# setup-geoip.sh — install the Nginx GeoIP2 module and GeoLite2-Country DB.
#
# Usage:
#   setup-geoip.sh --license-key KEY [--db-dir DIR] [--reload] [--dry-run]
#
# MaxMind requires a free account + license key to download GeoLite2:
# https://www.maxmind.com/en/geolite2/signup — the key is only used for
# this one download and is never written to disk by this script.
# Without --license-key the script installs the module and checks for an
# existing database, but cannot download a fresh one.
set -euo pipefail

DB_DIR="/etc/nginx/geoip"
LICENSE_KEY=""
RELOAD=0
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --license-key) LICENSE_KEY="$2"; shift 2 ;;
        --db-dir) DB_DIR="$2"; shift 2 ;;
        --reload) RELOAD=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

run() {
    if [ "$DRY_RUN" -eq 1 ]; then echo "+ $*"; else "$@"; fi
}

if [ "$(id -u)" -ne 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "Run as root (or use --dry-run to preview)." >&2
    exit 1
fi

run apt-get update -qq
run apt-get install -y -qq libnginx-mod-http-geoip2 curl
run mkdir -p "$DB_DIR"

DB_FILE="$DB_DIR/GeoLite2-Country.mmdb"
if [ -f "$DB_FILE" ]; then
    echo "Database already present: $DB_FILE (leaving it in place)"
elif [ -n "$LICENSE_KEY" ]; then
    # MaxMind's permalink returns a .tar.gz; extract just the .mmdb.
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    run curl -fsSL -o "$TMP/geolite.tar.gz" \
        "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${LICENSE_KEY}&suffix=tar.gz"
    run tar -xzf "$TMP/geolite.tar.gz" -C "$TMP"
    run cp "$TMP"/GeoLite2-Country_*/GeoLite2-Country.mmdb "$DB_FILE"
    run chmod 644 "$DB_FILE"
    [ "$DRY_RUN" -eq 1 ] || echo "Downloaded: $DB_FILE"
else
    echo "No --license-key given and no database found at $DB_FILE." >&2
    echo "Get a free key at https://www.maxmind.com/en/geolite2/signup, then re-run with --license-key." >&2
    exit 1
fi

if [ "$RELOAD" -eq 1 ]; then
    run nginx -t
    run systemctl reload nginx
    echo "Nginx config tested and reloaded."
else
    echo "Next: add the http{}/server{} snippets from nginx-geo-block.conf,"
    echo "copy blocked-countries.conf to /etc/nginx/, then: nginx -t && systemctl reload nginx"
fi
