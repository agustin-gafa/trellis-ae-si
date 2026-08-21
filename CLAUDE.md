# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository structure

This is a **Trellis** (Ansible-powered LEMP provisioning/deploy stack) monorepo hosting two independent
**Bedrock** WordPress sites, siblings on disk as Trellis expects:

- `trellis/` — Ansible playbooks, roles, and inventory that provision servers and deploy the sites. This
  directory's own repo is `trellis-ae-si` (`git@github.com:agustin-gafa/trellis-ae-si.git` — the local
  checkout folder name may differ, e.g. `rkn.staging.com`).
- `site-swedishinstitute/` — Bedrock site for `swedishinstitute.edu`, own repo
  (`git@github.com-si:agustin-gafa/swedishinstitute.git`).
- `site-aeinstitute/` — Bedrock site for `aeinstitute.net`, own repo
  (`git@github.com-ae:agustin-gafa/aeinstitute.git`).

These are three separate git repositories that must live as sibling directories on disk (as they do here)
for Trellis's relative `local_path` references to work. See `README.md` for the full deploy/SSH runbook.

Both sites are configured as **WordPress multisite (subdomain)** installs and only exist as a `staging`
environment currently (see `trellis/hosts/staging` — single droplet `178.156.244.142`, both sites deployed
there). There is no `production` inventory populated yet, and no local `site/` checkout — the
`trellis/group_vars/development/wordpress_sites.yml` entry (`rkn.staging.com`) is unused scaffolding from
`trellis-cli new`, not an active site.

Site repos are deployed from their own GitHub repos (`git@github.com-si:...`, `git@github.com-ae:...` — note
the custom SSH host aliases per site), not pushed from this monorepo; `site-swedishinstitute/` and
`site-aeinstitute/` here are meant to be local Bedrock checkouts used for editing before pushing to those
repos.

**Known gotcha:** as of 2026-08-21, both `site-aeinstitute/` and `site-swedishinstitute/` here are stale —
each is committed as a plain directory inside this monorepo's own `.git` (no `.git` of its own, not a
submodule) and only holds Bedrock scaffolding (`.gitkeep` placeholders, no theme code). The real code
lives only in the actual per-site repos — `aeinstitute` (`git@github.com:agustin-gafa/aeinstitute.git`)
and `swedishinstitute` (`git@github.com:agustin-gafa/swedishinstitute.git`) — each of which has its own
`CLAUDE.md`, `README.md`, and `DEPLOYMENT.md`; read those directly for that site's architecture and deploy
runbook instead of relying on these folders. On this machine, the real checkouts live under Devilbox at
`/srv/http/devilbox/data/www/aeinstitute` and `/srv/http/devilbox/data/www/swedishinstitute` — not as
siblings of `trellis/`. This is harmless for staging deploys (`trellis deploy` pulls from `repo:` on the
server, not from `local_path`); these folders only matter if you actually want a self-contained sibling
tree for `trellis-cli`, and would need the real repos cloned into them first.

Each site's `web/app/plugins/*`, `web/app/themes/twentytwentyfive/`, and `web/wp` are gitignored — they're
installed via Composer (`wp-theme/twentytwentyfive` is pulled as a Composer package), not committed.

## Commands

All Trellis (`trellis` CLI or raw `ansible-playbook`) commands run **from `trellis/`**. All Composer/Pest
commands run **from the relevant `site-*/` directory**.

### Site (Bedrock) — run inside `site-swedishinstitute/` or `site-aeinstitute/`

```bash
composer install              # install PHP dependencies
composer lint                 # Laravel Pint, check only (pint --test)
composer lint:fix             # Laravel Pint, auto-fix
composer test                 # run Pest test suite
./vendor/bin/pest tests/Feature/ExampleTest.php   # run a single test file
./vendor/bin/pest --filter=<name>                 # run a single test by name
```

### Trellis — run inside `trellis/` (requires `trellis-cli`; falls back to `ansible-playbook` directly)

```bash
trellis provision staging          # provision the staging server (reconfigures the server itself)
trellis deploy staging <site>      # deploy one site's code, e.g. `trellis deploy staging swedishinstitute.edu`
trellis ssh staging                # SSH to the staging host
trellis vault edit -f group_vars/staging/vault.yml   # edit encrypted secrets
trellis rollback staging <site>    # roll back the last deploy of a site
```

`provision` and `deploy` are not interchangeable: `provision` applies infra changes (PHP/nginx/MySQL
config, vault values, server packages); `deploy` only pulls/builds a site's code. A code-only change never
needs `provision`; an infra-only change is never applied by `deploy`.

Site names for `deploy`/`rollback`/etc. are the top-level keys in
`trellis/group_vars/<env>/wordpress_sites.yml` (`swedishinstitute.edu`, `aeinstitute.net`), not the local
directory names.

On the server, each site's deployed code lives at `/srv/www/<site>/current/` (a symlink to the active
release — never edit files there directly, changes are lost on the next deploy; useful only for
debugging: logs, `wp <command> --allow-root`, etc.).

## Architecture: how the pieces connect

- **`trellis/group_vars/<env>/wordpress_sites.yml`** is the source of truth per environment: it maps a site
  key (e.g. `swedishinstitute.edu`) to its `local_path` (the sibling `site-*` checkout Trellis deploys from),
  its `repo`, domains (`site_hosts`), and multisite/SSL/cache settings. Adding or reconfiguring a site starts
  here, in the matching environment file (`development/`, `staging/`, `production/`).
- **`trellis/group_vars/<env>/vault.yml`** holds the Ansible-Vault-encrypted secrets (DB passwords, salts,
  per-site env vars) referenced by the matching `main.yml`/`wordpress_sites.yml` via `vault_*` variables.
  Never edit it with a plain editor — use `trellis vault edit`.
- **`trellis/hosts/<env>`** is the Ansible inventory — which server IPs belong to which env/group (`web`,
  `db`, etc.). Both sites currently share the one staging box.
- **`trellis/deploy-hooks/build-before.yml` / `build-after.yml`** are where per-deploy asset-build steps
  (e.g. `npm run build` for a Sage theme) would run; both are currently just commented-out Sage boilerplate,
  meaning deploys here do no asset build step.
- **`trellis/roles/`** are the first-party Ansible roles (nginx, php, mariadb, redis, memcached, letsencrypt,
  wp-cli, deploy, etc.) invoked by the top-level playbooks (`server.yml` provisions, `deploy.yml` deploys,
  `rollback.yml` rolls back); `trellis/vendor/roles/` holds third-party Galaxy roles pulled per
  `requirements.yml`/`galaxy.yml`. Don't hand-edit `vendor/roles/`.
- **Each `site-*/`** is a standard Bedrock layout: `web/app/{plugins,themes,mu-plugins,uploads}` (WP content,
  mostly Composer-managed and gitignored), `web/wp` (WordPress core, gitignored), `config/environments/*.php`
  (per-`WP_ENV` overrides layered on `config/application.php`), and `.env`/`.env.example` for local secrets —
  Trellis populates the real `.env` on the server from `vault_wordpress_sites` at deploy time.
- **Multisite**: both sites run subdomain multisite (`multisite.subdomains: true`), so `site_hosts` for each
  includes both the root domain and at least one subdomain (`info.staging-*.rockinmedia.space`); new
  subdomains/sites need a matching `site_hosts` entry and DNS record, not just a WP admin action.
