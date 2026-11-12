#!/usr/bin/env bash
# Uploads a built site to the web server over FTP, replacing what is there.
# Usage: DEPLOY_FTP_HOST=… DEPLOY_FTP_USER=… DEPLOY_FTP_PASSWORD=… \
#        [DEPLOY_FTP_PORT=21] [DEPLOY_FTP_DIR=/] [DEPLOY_FTP_TLS=verify|encrypt|off] \
#        scripts/deploy.sh <dist dir>
set -euo pipefail

dist="${1:?usage: deploy.sh <dist dir>}"
for name in DEPLOY_FTP_HOST DEPLOY_FTP_USER DEPLOY_FTP_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "deploy: $name is not set" >&2
    exit 1
  fi
done
if [ ! -f "$dist/index.html" ]; then
  echo "deploy: $dist/index.html is missing; build the site first" >&2
  exit 1
fi

# verify: TLS with a certificate the runner trusts. encrypt: TLS, any
# certificate (a panel's self-signed one). off: plain FTP, password in clear.
case "${DEPLOY_FTP_TLS:-verify}" in
  verify) tls="set ftp:ssl-force true; set ftp:ssl-protect-data true; set ssl:verify-certificate true" ;;
  encrypt) tls="set ftp:ssl-force true; set ftp:ssl-protect-data true; set ssl:verify-certificate false" ;;
  off) tls="set ftp:ssl-allow false" ;;
  *) echo "deploy: DEPLOY_FTP_TLS must be verify, encrypt or off" >&2; exit 1 ;;
esac

# The password reaches lftp through the environment, not the command line.
# The server's own files survive --delete: aaPanel's .user.ini, the
# certificate challenge folder and .htaccess.
export LFTP_PASSWORD="$DEPLOY_FTP_PASSWORD"
lftp -c "
set cmd:fail-exit true
set net:max-retries 2
set net:timeout 30
$tls
open --env-password -u '$DEPLOY_FTP_USER' -p ${DEPLOY_FTP_PORT:-21} '$DEPLOY_FTP_HOST'
mirror --reverse --delete --no-perms --parallel=4 \
  --exclude-glob .user.ini --exclude-glob .well-known/ --exclude-glob .htaccess \
  '$dist/' '${DEPLOY_FTP_DIR:-/}'
"
echo "deploy: uploaded $dist to $DEPLOY_FTP_HOST:${DEPLOY_FTP_DIR:-/}"
