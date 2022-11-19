local _, ns = ...

local tocversion = select(4, GetBuildInfo())
local isClassic = tocversion < 40000

ns.tocversion = tocversion
ns.isClassic = isClassic
ns.isVanilla = tocversion >= 10000 and tocversion < 20000
ns.isTBC = tocversion >= 20000 and tocversion < 30000
ns.isWrath = tocversion >= 30000 and tocversion < 40000
ns.isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

-- Imports
local LSM = LibStub("LibSharedMedia-3.0")

-- Register statusbar textures
LSM:Register("statusbar", "Glamour7", [[Interface\AddOns\NugEnergy\media\textures\statusbar.tga]])
LSM:Register("statusbar", "Glamour7NoArt", [[Interface\AddOns\NugEnergy\media\textures\statusbar3.tga]])
LSM:Register("statusbar", "NugEnergyVertical", [[Interface\AddOns\NugEnergy\media\textures\vstatusbar.tga]])

-- Register fonts
LSM:Register("font", "Gidole Regular", [[Interface\AddOns\NugEnergy\media\fonts\Gidole-Regular.ttf]])
LSM:Register("font", "OpenSans Bold", [[Interface\AddOns\NugEnergy\media\fonts\OpenSans-Bold.ttf]])
LSM:Register("font", "OpenSans Light", [[Interface\AddOns\NugEnergy\media\fonts\OpenSans-Light.ttf]])
LSM:Register("font", "OpenSans Medium", [[Interface\AddOns\NugEnergy\media\fonts\OpenSans-Medium.ttf]])
LSM:Register("font", "OpenSans Regular", [[Interface\AddOns\NugEnergy\media\fonts\OpenSans-Regular.ttf]])
