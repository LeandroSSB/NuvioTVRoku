#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Roda todos os contratos em ordem; exit != 0 se qualquer um falhar.
cd "$(dirname "$0")"
RC=0
for c in 01-wellknown 02-auth 03-addons 04-catalog-stream 05-meta 06-subs 07-profiles 08-refresh 09-addon-walk 10-streams 11-subs; do
    echo
    if [ -f "$c.sh" ]; then
        bash "$c.sh" || RC=1
    else
        echo "== $c: ainda não implementado (skip)"
    fi
done
echo
if [ "$RC" -eq 0 ]; then echo "CONTRATOS: VERDE"; else echo "CONTRATOS: VERMELHO"; fi
exit $RC
