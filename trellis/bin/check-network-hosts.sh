#!/usr/bin/env bash
#
# Reports blogs of a WordPress network whose host is not declared in site_hosts.
#
# nginx serves this server by wildcard, but the Let's Encrypt certificate only
# covers the hosts declared in site_hosts. A blog whose host is not there is
# reachable and answers, and its TLS handshake fails: from the outside that
# looks like the site being broken, and behind a proxy it surfaces as a 525.
#
# It reports and does not fail. A host can be legitimately undeclared for a
# while, which is exactly the case while a main domain has not been moved yet,
# and a deploy should not be blocked by a state someone already knows about.
set -uo pipefail

release_path="${1:-}"
shift || true
declared=("$@")

if [[ -z "$release_path" || ! -d "$release_path" ]]; then
    echo "No release at '$release_path', nothing to check."
    exit 0
fi

cd "$release_path" || exit 0

mapfile -t blog_urls < <(wp site list --field=url --path=web/wp --skip-plugins --skip-themes 2>/dev/null)

if [[ "${#blog_urls[@]}" -eq 0 ]]; then
    echo "Could not read the blog list, skipping."
    exit 0
fi

uncovered=0

for url in "${blog_urls[@]}"; do
    host="${url#*://}"
    host="${host%%/*}"
    covered=0

    for d in "${declared[@]}"; do
        [[ "$host" == "$d" ]] && covered=1 && break
    done

    if [[ "$covered" -eq 1 ]]; then
        echo "ok                 $host"
    else
        echo "NO DECLARADO       $host  (no está en site_hosts, así que el certificado no lo cubre)"
        uncovered=$((uncovered + 1))
    fi
done

if [[ "$uncovered" -gt 0 ]]; then
    echo "Hosts sin cobertura de certificado: $uncovered. Declararlos en site_hosts exige que su DNS apunte ya a este servidor."
fi

exit 0
