#!/usr/bin/env bash
# Copies a built site to the web server over SSH, replacing what is there.
# Usage: DEPLOY_HOST=… DEPLOY_USER=… DEPLOY_PATH=… DEPLOY_SSH_KEY=… \
#        DEPLOY_KNOWN_HOSTS=… [DEPLOY_PORT=22] scripts/deploy.sh <dist dir>
set -euo pipefail

dist="${1:?usage: deploy.sh <dist dir>}"
for name in DEPLOY_HOST DEPLOY_USER DEPLOY_PATH DEPLOY_SSH_KEY DEPLOY_KNOWN_HOSTS; do
  if [ -z "${!name:-}" ]; then
    echo "deploy: $name is not set" >&2
    exit 1
  fi
done
if [ ! -f "$dist/index.html" ]; then
  echo "deploy: $dist/index.html is missing; build the site first" >&2
  exit 1
fi
# --delete below empties whatever DEPLOY_PATH names, so refuse anything but a
# site's own folder.
case "$DEPLOY_PATH" in
  /*/*/*) ;;
  *) echo "deploy: DEPLOY_PATH must be an absolute path at least three folders deep" >&2; exit 1 ;;
esac

work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT
printf '%s\n' "$DEPLOY_SSH_KEY" > "$work/key"
chmod 600 "$work/key"
printf '%s\n' "$DEPLOY_KNOWN_HOSTS" > "$work/known_hosts"

# The host key is pinned: an unknown or changed key stops the deploy.
ssh_command="ssh -i $work/key -p ${DEPLOY_PORT:-22} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$work/known_hosts"

# The server's own files in the folder survive --delete: aaPanel's .user.ini
# and the certificate challenge folder.
rsync --archive --compress --delete \
  --filter='P .user.ini' --filter='P .well-known/' --filter='P .htaccess' \
  -e "$ssh_command" \
  "$dist/" "$DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH/"
echo "deploy: copied $dist to $DEPLOY_HOST:$DEPLOY_PATH"
