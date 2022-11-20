local _, ns = ...

-- Each table under default has it's own settings page
local defaults = {}

defaults.appearance = {
    bar = {
        -- general
        show                = true,
        strata              = "MEDIUM",
        level               = 1,
        texture             = "Glamour7",
        orientation         = "HORIZONTAL",

        -- color
        color               = {0.87, 0.75, 0.08, 1},

        -- size
        scale               = 1,
        width               = 155,
        height              = 19,

        -- position
        point               = "CENTER",
        offsetX             = 0,
        offsetY             = 0,

        -- children
        background = {
            show            = true,
            scaleFactor     = 0.3
        },
        border = {
            show            = true,
            type            = "2PX"
        },
        spark = {
            show            = true,
            layer           = "ARTWORK",
            subLayer        = 4,
            position        = {"CENTER", "NugEnergyStatusBar", "TOP", 0, 0}
        }
    },
    text = {
        -- general
        show                = true,
        strata              = "MEDIUM",
        level               = 2,
        color               = {1, 1, 1, 1},

        -- font
        fontName            = "OpenSans Bold",
        fontSize            = 16,
        fontFlags           = "",

        --position
        point               = "RIGHT",
        offsetX             = 0,
        offsetY             = 0,
        justifyH            = "CENTER",
        justifyV            = "MIDDLE",
    }
}

defaults.behaviors = {
    plc = {
        isEnabled           = true,
        lowThreshold        = 0,
        lowColor            = {0.90, 0.10, 0.10},
        highThreshold       = 1,
        highColor           = {0.27, 0.76, 0.20},
    },
    fader = {
        isEnabled           = true,
        fadeBar             = true,
        fadeText            = true,
        outOfCombatAlpha    = 0.5,
        delay               = 5,
        duration            = 1,
    },
    spenderFeedback = {
        isEnabled           = true,
        duration            = 0.5,
    },
    alert = {
        isEnabled           = false
    },
    textThrottler = {
        isEnabled           = false,
        throttleFactor      = 5,
    },
    execute = {
        isEnabled           = false,
        healthPercent       = 0.2,
        color               = {0.90, 0.10, 0.10, 1},
    }
}

NUGENERGY_DEFAULTS = { profile = defaults }
