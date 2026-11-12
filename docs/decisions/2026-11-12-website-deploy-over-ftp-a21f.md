# Website deployed over FTP

Status: accepted — 2026-11-12

Replaces the transport in
[Website served from the owner's server, deployed by GitHub Actions](2026-11-12-website-hosting-own-server-2b64.md);
the rest of that record stands.

## Context

The earlier record copied the build with `rsync` over SSH, which needs a shell
user and a key on the server. The owner deploys to this server with the FTP
accounts aaPanel creates per site, and wants the website to go the same way.

## Decision

- `site/scripts/deploy.sh` uploads `site/dist` with `lftp mirror` over FTP
  using the site's own FTP account. The job installs `lftp` on the runner.
- TLS is asked for by default and the certificate verified
  (`SITE_DEPLOY_FTP_TLS=verify`). `encrypt` accepts any certificate, for the
  panel's self-signed one; `off` is plain FTP. The owner sets it as a
  repository variable.
- Host, user, password and port are GitHub Actions secrets.

## Consequences

- No shell account or SSH key on the server for deploys; the FTP account
  reaches the site folder only.
- With `encrypt` the server's identity is not proven; with `off` the password
  travels in clear text.
- FTP has no checksums: `lftp` decides what to upload by size and time.
- The server must allow FTP's passive ports from GitHub's runners.
