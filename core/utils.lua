local _, ns = ...

-- API locals
local unpack = unpack
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local str_match = string.match
local GetCVar = GetCVar

-- Color utils

local _rgb2hsv = function(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local max, min = math_max(r, g, b), math_min(r, g, b)
    local h, s, v
    v = max

    local d = max - min
    if (max == 0) then
        s = 0
    else
        s = d / max
    end

    if (max == min) then
        h = 0 -- achromatic
    else
        if (max == r) then
            h = (g - b) / d
            if (g < b) then
                h = h + 6
            end
        elseif (max == g) then
            h = (b - r) / d + 2
        elseif (max == b) then
            h = (r - g) / d + 4
        end
        h = h / 6
    end

    return h, s, v
end

local _hsv2rgb = function(h, s, v)
    local r, g, b

    local i = math_floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if (i == 0) then
        r, g, b = v, t, p
    elseif (i == 1) then
        r, g, b = q, v, p
    elseif (i == 2) then
        r, g, b = p, v, t
    elseif (i == 3) then
        r, g, b = p, q, v
    elseif (i == 4) then
        r, g, b = t, p, v
    elseif (i == 5) then
        r, g, b = v, p, q
    end

    return r * 255, g * 255, b * 255
end

local hsvShift = function(src, hm, sm, vm)
    local r, g, b = unpack(src)
    local h, s, v = _rgb2hsv(r, g, b)

    -- rollover on hue
    local h2 = h + hm
    if (h2 < 0) then
        h2 = h2 + 1
    end
    if (h2 > 1) then
        h2 = h2 - 1
    end

    local s2 = s + sm
    if (s2 < 0) then
        s2 = 0
    end
    if (s2 > 1) then
        s2 = 1
    end

    local v2 = v + vm
    if (v2 < 0) then
        v2 = 0
    end
    if (v2 > 1) then
        v2 = 1
    end

    local r2, g2, b2 = _hsv2rgb(h2, s2, v2)

    return r2, g2, b2
end

-- UI utils
local _getPmult = function()
    local res = GetCVar("gxWindowedResolution")
    if (res) then
        local _, h = str_match(res, "(%d+)x(%d+)")
        return (768 / h) / UIParent:GetScale()
    end
    return 1
end

local pixelPerfect = function(size)
    local pmult = _getPmult()
    return floor(size / pmult + 0.5) * pmult
end

-- Table utils

local readonly = function(t)
    local mt = {
        __index = t,
        __newindex = function(...)
            error("Attempt to update a read-only table", 2)
        end
    }
    return setmetatable({}, mt)
end

local observable = function(t, listeners)
    local mt = {
        __index = function(_, k)
            return t[k]
        end,
        __newindex = function(_, k, v)
            t[k] = v
            for _, listener in ipairs(listeners[k] or {}) do
                listener(v)
            end
        end
    }
    return setmetatable({}, mt)
end

ns.utils = {
    hsvShift = hsvShift,
    pixelPerfect = pixelPerfect,
    readonly = readonly,
    observable = observable
}
