# Website served from the owner's server, deployed by GitHub Actions

Status: accepted — 2026-11-12

Replaces the hosting part of
[Website in `site/`, built with Astro and Starlight](2026-11-08-website-astro-starlight-a04b.md);
the rest of that record stands.

## Context

The earlier record put the site on Cloudflare Pages. The owner runs
`transflex.aiaz.io` on a web server of their own, managed with aaPanel, and
wants the new site there rather than on another service.

## Decision

- The site is served as static files by that server. No Node or build runs on
  it.
- The `Deploy site` job in `.github/workflows/site.yml` builds `site/` and
  copies `site/dist` to the server with `rsync` over SSH
  (`site/scripts/deploy.sh`), after the checks pass, on pushes to `main` that
  touch `site/`.
- The job is off until the repository variable `SITE_DEPLOY_ENABLED` is
  `true`. The server address, user, folder, a deploy-only SSH key and the
  server's host key are GitHub Actions secrets.
- The server's host key is pinned; the job never accepts an unknown key.

## Consequences

- The repository holds a credential that can write to the site folder. It is a
  key used for nothing else, for a user that should reach nothing else.
- No preview per pull request; `npm run dev` and the `Build and check site`
  job stand in for it.
- The server's SSH port must accept connections from GitHub's runners.
- The copy deletes what is not in the build, except `.user.ini`,
  `.well-known/` and `.htaccess`.

## Alternatives rejected

- Download a build archive and upload it by hand in aaPanel: no credential,
  but every change to the site waits for someone to remember.
- Let the server pull the repository and build on a webhook: needs Node on the
  server, and a failed build is hard to see.
