-- Shim de localisation framework-agnostique (remplace @qb-core/shared/locale.lua).
-- Reproduit l'API `Lang:t('a.b.c', { var = x })` avec interpolation %{var}.
local lang = GetConvar('esx:locale', GetConvar('ox:locale', 'fr'))
local phrases = (Locales and (Locales[lang] or Locales.fr or Locales.en)) or {}

local function interp(str, vars)
    if not vars then return str end
    return (str:gsub('%%{(.-)}', function(key)
        local v = vars[key]
        if v == nil then return '%{' .. key .. '}' end
        return tostring(v)
    end))
end

Lang = {
    t = function(_, key, vars)
        local node = phrases
        for part in string.gmatch(key, '[^.]+') do
            if type(node) ~= 'table' then node = nil break end
            node = node[part]
        end
        if type(node) ~= 'string' then return key end
        return interp(node, vars)
    end,
}
