#!/usr/bin/env python3
"""Patch Coolify LiteLLM docker-compose on tha for litellm.theunnamedroads.com.
Run on the server: python3 apply-litellm-domain-tha.py /path/to/docker-compose.yml
"""
import pathlib
import sys

PATH = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/data/coolify/services/kkswc8gokk84c0o8oo84w44w/docker-compose.yml")

NEW_TRAEFIK = [
    "      - traefik.enable=true",
    "      - traefik.http.middlewares.gzip.compress=true",
    "      - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https",
    "      - traefik.http.routers.http-0-kkswc8gokk84c0o8oo84w44w-litellm.entryPoints=http",
    "      - traefik.http.routers.http-0-kkswc8gokk84c0o8oo84w44w-litellm.middlewares=redirect-to-https",
    "      - 'traefik.http.routers.http-0-kkswc8gokk84c0o8oo84w44w-litellm.rule=Host(`litellm.theunnamedroads.com`) && PathPrefix(`/`)'",
    "      - traefik.http.routers.http-0-kkswc8gokk84c0o8oo84w44w-litellm.service=http-0-kkswc8gokk84c0o8oo84w44w-litellm",
    "      - traefik.http.routers.https-0-kkswc8gokk84c0o8oo84w44w-litellm.entryPoints=https",
    "      - 'traefik.http.routers.https-0-kkswc8gokk84c0o8oo84w44w-litellm.middlewares=gzip,redirect-to-https'",
    "      - 'traefik.http.routers.https-0-kkswc8gokk84c0o8oo84w44w-litellm.rule=Host(`litellm.theunnamedroads.com`) && PathPrefix(`/`)'",
    "      - traefik.http.routers.https-0-kkswc8gokk84c0o8oo84w44w-litellm.tls.certresolver=letsencrypt",
    "      - traefik.http.routers.https-0-kkswc8gokk84c0o8oo84w44w-litellm.tls=true",
    "      - traefik.http.routers.https-0-kkswc8gokk84c0o8oo84w44w-litellm.service=http-0-kkswc8gokk84c0o8oo84w44w-litellm",
    "      - traefik.http.services.http-0-kkswc8gokk84c0o8oo84w44w-litellm.loadbalancer.server.port=4000",
    "      - 'caddy_0.encode=zstd gzip'",
    "      - 'caddy_0.handle_path.0_reverse_proxy={{upstreams 4000}}'",
    "      - 'caddy_0.handle_path=/*'",
    "      - caddy_0.header=-Server",
    "      - 'caddy_0.try_files={path} /index.html /index.php'",
    "      - 'caddy_0=https://litellm.theunnamedroads.com'",
    "      - caddy_ingress_network=kkswc8gokk84c0o8oo84w44w",
]


def main() -> None:
    text = PATH.read_text()
    bak = PATH.with_suffix(PATH.suffix + ".bak.litellm-domain")
    bak.write_text(text)
    print(f"Backup: {bak}")

    lines = text.splitlines()
    out: list[str] = []
    i = 0
    in_litellm = False
    while i < len(lines):
        line = lines[i]
        if line.startswith("  litellm:"):
            in_litellm = True
            out.append(line)
            i += 1
            continue
        if in_litellm and line.startswith("  postgres:"):
            in_litellm = False
            out.append(line)
            i += 1
            continue

        if in_litellm and line.strip().startswith("SERVICE_URL_LITELLM_4000:"):
            out.append("      SERVICE_URL_LITELLM_4000: 'https://litellm.theunnamedroads.com'")
            i += 1
            continue
        if in_litellm and line.strip().startswith("COOLIFY_FQDN:"):
            out.append("      COOLIFY_FQDN: litellm.theunnamedroads.com")
            i += 1
            continue
        if in_litellm and line.strip().startswith("COOLIFY_URL:"):
            out.append("      COOLIFY_URL: 'https://litellm.theunnamedroads.com'")
            i += 1
            continue

        if in_litellm and line.strip() == "labels:":
            out.append(line)
            i += 1
            # copy coolify labels until first traefik line (quoted or not)
            while i < len(lines) and "traefik" not in lines[i]:
                out.append(lines[i])
                i += 1
            # skip all traefik + caddy labels (Traefik rules may be quoted: - 'traefik...)
            while i < len(lines) and lines[i].startswith("      -") and (
                "traefik" in lines[i] or "caddy" in lines[i]
            ):
                i += 1
            out.extend(NEW_TRAEFIK)
            continue

        out.append(line)
        i += 1

    PATH.write_text("\n".join(out) + "\n")
    print(f"Updated: {PATH}")


if __name__ == "__main__":
    main()
