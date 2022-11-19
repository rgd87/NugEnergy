local _, ns = ...

local NugEnergy = _G.NugEnergy

-- Libraries
local L = LibStub("AceLocale-3.0"):GetLocale("NugEnergy", true)
local LSM = LibStub("LibSharedMedia-3.0")

-- API locals
local unpack = unpack

-- Locals
local screenWidth = floor(GetScreenWidth())
local screenHeight = floor(GetScreenHeight())

local STRATA_VALUES = {
    ["BACKGROUND"] = L.BACKGROUND_UC,
    ["LOW"] = L.LOW_UC,
    ["MEDIUM"] = L.MEDIUM_UC,
    ["HIGH"] = L.HIGH_UC,
    ["DIALOG"] = L.DIALOG_UC,
    ["FULLSCREEN"] = L.FULLSCREEN_UC,
    ["FULLSCREEN_DIALOG"] = L.FULLSCREEN_DIALOG_UC,
    ["TOOLTIP"] = L.TOOLTIP_UC
}

local POINT_VALUES = {
    ["CENTER"] = L.CENTER_UC,
    ["LEFT"] = L.LEFT_UC,
    ["RIGHT"] = L.RIGHT_UC,
    ["TOP"] = L.TOP_UC,
    ["TOPLEFT"] = L.TOPLEFT_UC,
    ["TOPRIGHT"] = L.TOPRIGHT_UC,
    ["BOTTOM"] = L.BOTTOM_UC,
    ["BOTTOMLEFT"] = L.BOTTOMLEFT_UC,
    ["BOTTOMRIGHT"] = L.BOTTOMRIGHT_UC
}

local _get = function(transformer)
    transformer = transformer or function(t)
            return t
        end
    return function(info)
        local temp = NugEnergy.db.profile
        for _, v in ipairs(info) do
            local match = string.match(v, "^noarg_")
            if (match == nil) then
                temp = temp[v]
            end
        end
        return transformer(temp)
    end
end

local _set = function(transformer, onupdate)
    transformer = transformer or function(...)
            return ...
        end
    return function(info, ...)
        local temp = NugEnergy.db.profile
        for i = 1, #info - 1 do
            local v = info[i]
            local match = string.match(v, "^noarg_")
            if (match == nil) then
                temp = temp[v]
            end
        end
        temp[info[#info]] = transformer(...)
        if (onupdate) then
            onupdate()
        end
    end
end

local SETTINGS_CONFIG = {
    type = "group",
    order = 1,
    name = "NugEnergy",
    get = _get(),
    set = _set(),
    args = {
        general = {
            type = "group",
            order = 1,
            name = L.GENERAL,
            args = {
                generalHeader = {
                    type = "header",
                    order = 1,
                    name = L.GENERAL
                },
                unlock = {
                    type = "execute",
                    order = 1,
                    name = L.UNLOCK,
                    desc = L.UNLOCK_DESC,
                    width = 1,
                    func = function()
                        NugEnergy:Unlock()
                    end
                },
                lock = {
                    type = "execute",
                    order = 2,
                    name = L.LOCK,
                    desc = L.LOCK_DESC,
                    width = 1,
                    func = function()
                        NugEnergy:Lock()
                    end
                }
            }
        },
        appearance = {
            type = "group",
            order = 2,
            name = L.APPEARANCE,
            args = {
                bar = {
                    type = "group",
                    order = 1,
                    name = L.STATUS_BAR,
                    inline = true,
                    set = _set(
                        nil,
                        function()
                            NugEnergy.statusBar:Update()
                        end
                    ),
                    args = {
                        show = {
                            type = "toggle",
                            order = 1,
                            name = L.SHOW,
                            width = "full"
                        },
                        texture = {
                            type = "select",
                            order = 2,
                            name = L.TEXTURE,
                            values = LSM:HashTable("statusbar"),
                            dialogControl = "LSM30_Statusbar"
                        },
                        strata = {
                            type = "select",
                            order = 3,
                            name = L.STRATA,
                            values = STRATA_VALUES,
                            style = "dropdown"
                        },
                        level = {
                            type = "range",
                            order = 4,
                            name = L.LEVEL,
                            min = 0,
                            max = 10,
                            step = 1,
                            bigStep = 1
                        },
                        orientation = {
                            type = "select",
                            order = 5,
                            name = L.ORIENTATION,
                            values = {
                                ["HORIZONTAL"] = L.HORIZONTAL_UC,
                                ["VERTICAL"] = L.VERTICAL_UC
                            },
                            style = "dropdown"
                        },
                        noarg_Colors = {
                            type = "group",
                            order = 6,
                            name = L.COLORS,
                            inline = true,
                            get = _get(unpack),
                            set = _set(
                                function(r, g, b, a)
                                    return {r, g, b, a}
                                end,
                                function()
                                    NugEnergy.statusBar:Update()
                                end
                            ),
                            args = {
                                color = {
                                    type = "color",
                                    order = 1,
                                    name = L.COLOR,
                                    hasAlpha = true
                                }
                            }
                        },
                        noarg_Size = {
                            type = "group",
                            order = 7,
                            name = L.SIZE,
                            inline = true,
                            args = {
                                scale = {
                                    type = "range",
                                    order = 1,
                                    name = L.SCALE,
                                    min = 0.1,
                                    max = 10,
                                    step = 0.1
                                },
                                width = {
                                    type = "range",
                                    order = 2,
                                    name = L.WIDTH,
                                    min = 10,
                                    max = 1024,
                                    step = 0.01,
                                    bigStep = 1
                                },
                                height = {
                                    type = "range",
                                    order = 3,
                                    name = L.HEIGHT,
                                    min = 10,
                                    max = 1024,
                                    step = 0.01,
                                    bigStep = 1
                                }
                            }
                        },
                        noarg_Position = {
                            type = "group",
                            order = 8,
                            name = L.POSITION,
                            inline = true,
                            args = {
                                offsetX = {
                                    type = "range",
                                    order = 1,
                                    name = L.X_UC,
                                    softMin = 0,
                                    softMax = screenWidth,
                                    step = 0.01,
                                    bigStep = 1
                                },
                                offsetY = {
                                    type = "range",
                                    order = 2,
                                    name = L.Y_UC,
                                    softMin = -screenHeight,
                                    softMax = 0,
                                    step = 0.01,
                                    bigStep = 1
                                }
                            }
                        },
                        background = {
                            type = "group",
                            order = 9,
                            name = L.BACKGROUND,
                            inline = true,
                            set = _set(
                                nil,
                                function()
                                    NugEnergy.background:Update()
                                end
                            ),
                            args = {
                                show = {
                                    type = "toggle",
                                    order = 1,
                                    name = L.SHOW
                                },
                                scaleFactor = {
                                    type = "range",
                                    order = 2,
                                    name = L.SCALE_FACTOR,
                                    desc = L.SCALE_FACTOR_DESC,
                                    min = 0,
                                    max = 1,
                                    step = 0.01,
                                    bigStep = 0.1
                                }
                            }
                        },
                        border = {
                            type = "group",
                            order = 10,
                            name = L.BORDER,
                            inline = true,
                            set = _set(
                                nil,
                                function()
                                    NugEnergy.border:Update()
                                end
                            ),
                            args = {
                                show = {
                                    type = "toggle",
                                    order = 1,
                                    name = L.SHOW
                                },
                                type = {
                                    type = "select",
                                    order = 2,
                                    name = L.TYPE,
                                    values = {
                                        ["1PX"] = L.BORDER_1PX,
                                        ["2PX"] = L.BORDER_2PX,
                                        ["3PX"] = L.BORDER_3PX,
                                        ["TOOLTIP"] = L.BORDER_TOOLTIP,
                                        ["STATUSBAR"] = L.BORDER_STATUS
                                    },
                                    style = "dropdown"
                                }
                            }
                        },
                        spark = {
                            type = "group",
                            order = 11,
                            name = L.SPARK,
                            inline = true,
                            set = _set(
                                nil,
                                function()
                                    NugEnergy.spark:Update()
                                end
                            ),
                            args = {
                                show = {
                                    type = "toggle",
                                    order = 1,
                                    name = L.SHOW
                                }
                            }
                        }
                    }
                },
                text = {
                    type = "group",
                    order = 2,
                    name = L.TEXT,
                    inline = true,
                    set = _set(
                        nil,
                        function()
                            NugEnergy.text:Update()
                        end
                    ),
                    args = {
                        show = {
                            type = "toggle",
                            order = 1,
                            name = L.SHOW,
                            width = "full"
                        },
                        color = {
                            type = "color",
                            order = 2,
                            name = L.COLOR,
                            hasAlpha = true,
                            get = _get(unpack),
                            set = _set(
                                function(r, g, b, a)
                                    return {r, g, b, a}
                                end,
                                function()
                                    NugEnergy.text:Update()
                                end
                            )
                        },
                        strata = {
                            type = "select",
                            order = 3,
                            name = L.STRATA,
                            values = STRATA_VALUES,
                            style = "dropdown"
                        },
                        level = {
                            type = "range",
                            order = 4,
                            name = L.LEVEL,
                            min = 0,
                            max = 10,
                            step = 1,
                            bigStep = 1
                        },
                        noarg_Font = {
                            type = "group",
                            order = 5,
                            name = L.FONT,
                            inline = true,
                            args = {
                                fontName = {
                                    type = "select",
                                    order = 1,
                                    name = L.FONT_NAME,
                                    values = LSM:HashTable("font"),
                                    dialogControl = "LSM30_Font"
                                },
                                fontSize = {
                                    type = "range",
                                    order = 2,
                                    name = L.FONT_SIZE,
                                    min = 6,
                                    max = 64,
                                    step = 1
                                },
                                fontFlags = {
                                    type = "select",
                                    order = 3,
                                    name = L.FONT_STYLE,
                                    values = {
                                        [""] = L.NONE_UC,
                                        ["OUTLINE"] = L.OUTLINE_UC,
                                        ["THICKOUTLINE"] = L.THICKOUTLINE_UC,
                                        ["MONOCHROME"] = L.MONOCHROME_UC
                                    },
                                    style = "dropdown"
                                },
                            }
                        },
                        noarg_Position = {
                            type = "group",
                            order = 6,
                            name = L.POSITION,
                            inline = true,
                            args = {
                                point = {
                                    type = "select",
                                    order = 1,
                                    name = L.POINT,
                                    values = POINT_VALUES,
                                    style = "dropdown"
                                },
                                offsetX = {
                                    type = "range",
                                    order = 2,
                                    name = L.X_UC,
                                    softMin = 0,
                                    softMax = screenWidth,
                                    step = 0.01,
                                    bigStep = 1
                                },
                                offsetY = {
                                    type = "range",
                                    order = 3,
                                    name = L.Y_UC,
                                    softMin = -screenHeight,
                                    softMax = 0,
                                    step = 0.01,
                                    bigStep = 1
                                },
                                justifyH = {
                                    type = "select",
                                    order = 4,
                                    name = L.JUSTIFY_H,
                                    values = {
                                        ["LEFT"] = L.LEFT_UC,
                                        ["RIGHT"] = L.RIGHT_UC,
                                        ["CENTER"] = L.CENTER_UC
                                    },
                                    style = "dropdown"
                                },
                                justifyV = {
                                    type = "select",
                                    order = 5,
                                    name = L.JUSTIFY_V,
                                    values = {
                                        ["TOP"] = L.TOP_UC,
                                        ["BOTTOM"] = L.BOTTOM_UC,
                                        ["MIDDLE"] = L.MIDDLE_UC
                                    },
                                    style = "dropdown"
                                }
                            }
                        }
                    }
                }
            }
        },
        behaviors = {
            type = "group",
            order = 3,
            name = L.BEHAVIORS,
            args = {
                plc = {
                    type = "group",
                    order = 1,
                    name = L.PLC_OVERRIDES,
                    inline = true,
                    set = _set(
                        nil,
                        function()
                            NugEnergy.plc:Update()
                        end
                    ),
                    args = {
                        isEnabled = {
                            type = "toggle",
                            order = 1,
                            name = L.ENABLED,
                            width = "full"
                        },
                        noarg_Low = {
                            type = "group",
                            order = 2,
                            name = L.LOW,
                            inline = true,
                            args = {
                                lowThreshold = {
                                    type = "range",
                                    order = 1,
                                    name = L.THRESHOLD,
                                    min = 0,
                                    max = 1,
                                    step = 0.01,
                                    bigStep = 0.1
                                },
                                lowColor = {
                                    type = "color",
                                    order = 2,
                                    name = L.COLOR,
                                    hasAlpha = false,
                                    get = _get(unpack),
                                    set = _set(
                                        function(r, g, b)
                                            return {r, g, b}
                                        end,
                                        function()
                                            NugEnergy.plc:Update()
                                        end
                                    ),
                                },
                            }
                        },
                        noarg_High = {
                            type = "group",
                            order = 3,
                            name = L.HIGH,
                            inline = true,
                            args = {
                                highThreshold = {
                                    type = "range",
                                    order = 1,
                                    name = L.THRESHOLD,
                                    min = 0,
                                    max = 1,
                                    step = 0.01,
                                    bigStep = 0.1
                                },
                                highColor = {
                                    type = "color",
                                    order = 2,
                                    name = L.COLOR,
                                    hasAlpha = false,
                                    get = _get(unpack),
                                    set = _set(
                                        function(r, g, b)
                                            return {r, g, b}
                                        end,
                                        function()
                                            NugEnergy.plc:Update()
                                        end
                                    ),
                                },
                            }
                        }
                    }
                },
                fader = {
                    type = "group",
                    order = 2,
                    name = L.FADER,
                    inline = true,
                    set = _set(
                        nil,
                        function()
                            NugEnergy.fader:Update()
                        end
                    ),
                    args = {
                        isEnabled = {
                            type = "toggle",
                            order = 1,
                            name = L.ENABLED
                        },
                        fadeBar = {
                            type = "toggle",
                            order = 2,
                            name = L.FADE_BAR
                        },
                        fadeText = {
                            type = "toggle",
                            order = 3,
                            name = L.FADE_TEXT
                        },
                        outOfCombatAlpha = {
                            type = "range",
                            order = 4,
                            name = L.OOC_ALPHA,
                            min = 0,
                            max = 1,
                            step = 0.01,
                            bigStep = 0.1
                        },
                        delay = {
                            type = "range",
                            order = 5,
                            name = L.DELAY,
                            min = 0,
                            max = 10,
                            step = 0.1,
                            bigStep = 1
                        },
                        duration = {
                            type = "range",
                            order = 6,
                            name = L.DURATION,
                            min = 0,
                            max = 10,
                            step = 0.1,
                            bigStep = 1
                        }
                    }
                },
                spenderFeedback = {
                    type = "group",
                    order = 3,
                    name = L.SPENDER_FEEDBACK,
                    inline = true,
                    set = _set(
                        nil,
                        function()
                            NugEnergy.spentBar:Update()
                        end
                    ),
                    args = {
                        isEnabled = {
                            type = "toggle",
                            order = 1,
                            name = L.ENABLED
                        },
                        duration = {
                            type = "range",
                            order = 2,
                            name = L.DURATION,
                            min = 0,
                            max = 10,
                            step = 0.1,
                            bigStep = 1
                        }
                    }
                },
                execute = {
                    type = "group",
                    order = 4,
                    name = L.EXECUTE,
                    inline = true,
                    args = {
                        isEnabled = {
                            type = "toggle",
                            order = 1,
                            name = L.ENABLED
                        },
                        healthPercent = {
                            type = "range",
                            order = 2,
                            name = L.HEALTH_PERCENT,
                            min = 0,
                            max = 1,
                            step = 0.01,
                            bigStep = 0.1
                        }
                    }
                },
                alert = {
                    type = "group",
                    order = 5,
                    name = L.ALERT,
                    inline = true,
                    set = _set(
                        nil,
                        function()
                            NugEnergy.alert:Update()
                        end
                    ),
                    args = {
                        isEnabled = {
                            type = "toggle",
                            order = 1,
                            name = L.ENABLED
                        }
                    }
                }
            }
        }
    }
}

function NugEnergy:SetupOptions()
    SETTINGS_CONFIG.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("NugEnergy", SETTINGS_CONFIG)
    local ACD = LibStub("AceConfigDialog-3.0")
    ACD:AddToBlizOptions("NugEnergy", "NugEnergy", nil, "general")
    ACD:AddToBlizOptions("NugEnergy", L.APPEARANCE, "NugEnergy", "appearance")
    ACD:AddToBlizOptions("NugEnergy", L.BEHAVIORS, "NugEnergy", "behaviors")
    ACD:AddToBlizOptions("NugEnergy", L.PROFILES, "NugEnergy", "profiles")
end
