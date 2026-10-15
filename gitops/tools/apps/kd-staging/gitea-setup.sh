#!/bin/sh
# Registers kd as Gitea's OpenID Connect source (idempotent). kd's admins group -> Gitea admin.
set -eu
mkdir -p "$(dirname "$GITEA_APP_INI")"
environment-to-ini --config "$GITEA_APP_INI"
gitea --config "$GITEA_APP_INI" migrate
if ! gitea --config "$GITEA_APP_INI" admin auth list | grep -Eq '(^|[[:space:]])kd([[:space:]]|$)'; then
  # Discovery goes through the hostAlias; if kd is not up yet this fails and the init container retries.
  gitea --config "$GITEA_APP_INI" admin auth add-oauth --name kd --provider openidConnect \
    --key gitea --secret "$GITEA_OIDC_SECRET" \
    --auto-discover-url "https://kd-staging.phillips-homelab.net/oidc/.well-known/openid-configuration" \
    --scopes "openid profile email groups" \
    --group-claim-name groups --admin-group admins
fi
