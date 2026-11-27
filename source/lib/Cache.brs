' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Cache — cache de SESSÃO em m.global (sem TTL de propósito: morre com o processo).
' Manifests por URL (conteúdo imutável na sessão): um play/search faz ~1 fetch de
' manifest por addon ao invés de N tasks refetchando a mesma URL. Init-guard
' hasField/addFields no 1º acesso (padrão do accessTokenCache do AuthClient).
' A interface de addons (CacheGetAddons/CacheSetAddons) existe por interface do
' plano MAS não é ligada aos consumers (decisão conservadora): enabled muda em
' runtime (toggle da tela de addons) e a invalidação cruzaria MainScene↔Tasks
' por 1 request economizado — leitura da tabela addons segue AO VIVO.

sub CacheInit()
    ' m.global AA por URL é impraticável (field por manifest) → UM AA url→manifest
    if not m.global.hasField("manifestCache") then
        m.global.addFields({ manifestCache: { } })
    end if
end sub

function CacheGetManifest(url as string) as object
    CacheInit()
    cache = m.global.manifestCache
    if cache.doesExist(url) then
        return cache[url]
    end if
    return invalid
end function

sub CacheSetManifest(url as string, manifest as object)
    CacheInit()
    cache = m.global.manifestCache
    cache[url] = manifest
end sub

' NÃO ligada (ver cabeçalho) — pronta p/ wiring futuro com chave de perfil
' (m.global.addonsListCache + m.global.addonsListProfile, invalidado no toggle).
function CacheGetAddons() as object
    if not m.global.hasField("addonsListCache") then
        return invalid
    end if
    return m.global.addonsListCache
end function

sub CacheSetAddons(addons as object)
    if m.global.hasField("addonsListCache") then
        m.global.addonsListCache = addons
    else
        m.global.addFields({ addonsListCache: addons, addonsListProfile: "" })
    end if
end sub
