-- Only for Paladins
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end

local KINGS_SPELL_ID = 20217          -- Blessing of Kings
local GREATER_KINGS_SPELL_ID = 25898  -- Greater Blessing of Kings
local kingsName = GetSpellInfo(KINGS_SPELL_ID)
local greaterKingsName = GetSpellInfo(GREATER_KINGS_SPELL_ID)

local frame = CreateFrame("Frame", "StreetKingsFrame", UIParent)
frame:SetWidth(200)
frame:SetHeight(200)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0, 0, 0, 0.8)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -10)
title:SetText("|cffffd700Street Kings|r")

-- Scrollable content
local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
scrollFrame:SetPoint("TOPLEFT", 10, -30)
scrollFrame:SetPoint("BOTTOMRIGHT", -10, 10)
local content = CreateFrame("Frame", nil, scrollFrame)
scrollFrame:SetScrollChild(content)
content:SetWidth(180)
content:SetHeight(1)

local buttons = {}

-- Check if a unit has any Kings buff
local function HasKings(unit)
    for i = 1, 40 do
        local name = UnitBuff(unit, i)
        if not name then break end
        if name == kingsName or name == greaterKingsName then
            return true
        end
    end
    return false
end

-- Check if a unit has any aura (buff or debuff) with "hardcore" in its name (case-insensitive)
local function HasHardcoreAura(unit)
    -- Check buffs
    for i = 1, 40 do
        local name = UnitBuff(unit, i)
        if not name then break end
        if string.find(string.lower(name), "hardcore") or string.find(string.lower(name), "ironman") then
            return true
        end
    end
    -- Check debuffs
    for i = 1, 40 do
        local name = UnitDebuff(unit, i)
        if not name then break end
        if string.find(string.lower(name), "hardcore") or string.find(string.lower(name), "ironman") then
            return true
        end
    end
    return false
end

-- Build a set of names of players in your party/raid
local function GetGroupNames()
    local names = {}
    if IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local name = UnitName("raid"..i)
            if name then names[name] = true end
        end
    elseif GetNumPartyMembers() > 0 then
        names[UnitName("player")] = true
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party"..i)
            if name then names[name] = true end
        end
    else
        names[UnitName("player")] = true
    end
    return names
end

-- Get bystanders missing Kings (range + LOS, minimal nesting)
local function GetBystandersMissingKings()
    local groupNames = GetGroupNames()
    local missing = {}
    for i = 1, 40 do
        local unit = "nameplate"..i
        -- First: basic unit validity checks (no call to UnitName yet)
        if UnitExists(unit)
           and UnitIsPlayer(unit)
           and UnitIsFriend("player", unit)
           and not UnitIsDeadOrGhost(unit)
           and UnitIsConnected(unit) then

            local name = UnitName(unit)

            -- Second: all buff / aura / group / range checks combined
            if not groupNames[name]
               and not HasHardcoreAura(unit)
               and not HasKings(unit)
               and IsSpellInRange(kingsName, unit) == 1 then

                table.insert(missing, unit)
            end
        end
    end
    return missing
end

-- Rebuild the button list (no combat hiding, uses correct spell+unit binding)
local function RefreshButtons()
    for _, btn in ipairs(buttons) do
        btn:Hide()
        btn:SetAttribute("unit", nil)
    end

    -- Combat check REMOVED – panel stays visible always

    local units = GetBystandersMissingKings()
    local btnHeight = 24
    local spacing = 2
    content:SetHeight(math.max(1, #units * (btnHeight + spacing)))

    for i, unit in ipairs(units) do
        local btn = buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, content, "SecureActionButtonTemplate")
            btn:SetHeight(btnHeight)
            btn:SetWidth(160)
            btn:SetNormalFontObject("GameFontNormal")
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 8, edgeSize = 16,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            })
            btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
            btn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.4, 0.4, 0.4, 1)
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.2, 0.2, 0.2, 1)
            end)
            -- Secure spell cast on the specific unit (no macrotext needed)
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("spell", kingsName)
            table.insert(buttons, btn)
        end

        btn:SetAttribute("unit", unit)
        btn:SetText(UnitName(unit))
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 0, -(i-1)*(btnHeight+spacing))
        btn:Show()
    end

    for i = #units + 1, #buttons do
        buttons[i]:Hide()
    end
end

local elapsed = 0
frame:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.5 then
        elapsed = 0
        RefreshButtons()
    end
end)

RefreshButtons()
