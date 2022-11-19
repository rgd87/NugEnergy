local NugEnergy = _G.NugEnergy

local _parseOptions = function(str)
    local fields = {}
    for opt, args in string.gmatch(str, "(%w*)%s*=%s*([%w%,%-%_%.%:%\\%']+)") do
        fields[opt:lower()] = tonumber(args) or args
    end
    return fields
end

local COMMANDS = {
    ["gui"] = function(v)
        InterfaceOptionsFrame_OpenToCategory("NugEnergy")
        InterfaceOptionsFrame_OpenToCategory("NugEnergy")
    end,
    ["lock"] = function()
        NugEnergy:Lock()
    end,
    ["unlock"] = function(v)
        NugEnergy:Unlock()
    end,
    ["markadd"] = function(v)
        local p = _parseOptions(v)
        local at = tonumber(p["at"])
        if at then
            NugEnergy.db.profile.marks[at] = true
            NugEnergy.markHandler:AddMark(at)
        end
    end,
    ["markdel"] = function(v)
        local p = _parseOptions(v)
        local at = tonumber(p["at"])
        if at then
            NugEnergy.db.profile.marks[at] = nil
            NugEnergy.markHandler:DeleteMark(at)
        end
    end,
    ["marklist"] = function(v)
        print("Current marks:")
        for p in pairs(NugEnergy.db.profile.marks) do
            print(string.format("    @%d", p))
        end
    end,
    ["reset"] = function(v)
        NugEnergy.statusBar:ResetPosition()
    end
}

local helpMessage = {
    "|cff00ffbb/nen gui|r",
    "|cff00ff00/nen lock|r",
    "|cff00ff00/nen unlock|r",
    "|cff00ff00/nen reset|r",
}

SLASH_NUGENERGY1 = "/nugenergy"
SLASH_NUGENERGY2 = "/nen"

function SlashCmdList.NUGENERGY(message)
    local cmd, args = string.match(message, "([%w%+%-%=]+) ?(.*)")
    if (not cmd or cmd == "help") then
        print("Usage:")
        for _, v in ipairs(helpMessage) do
            print(" - ", v)
        end
    end
    if (COMMANDS[cmd]) then
        COMMANDS[cmd](args)
    end
end