#!/usr/bin/env bash
# Contrato 01: descoberta de backend — GET /.well-known/nuvio.
# Congela o schema: service, backend_url, publishable_key (JWT), capabilities.email_password_auth.
source "$(dirname "$0")/lib.sh"

OFFICIAL_BACKEND="https://api.nuvio.tv"

for BACKEND in "$OFFICIAL_BACKEND" "$NUVIO_BACKEND_URL"; do
    RESP="$(wellknown "$BACKEND")"
    assert_contains "[$BACKEND] service" '"service":"nuvio"' "$RESP"
    assert_contains "[$BACKEND] backend_url" '"backend_url"' "$RESP"
    KEY="$(json_get "$RESP" .publishable_key)"
    assert_contains "[$BACKEND] publishable_key parece JWT" "eyJ" "$KEY"
    assert_eq "[$BACKEND] email_password_auth" "true" "$(json_get "$RESP" .capabilities.email_password_auth)"
done

finish_contract "01-wellknown"
