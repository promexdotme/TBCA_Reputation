-- TBCA_Reputation Core Logic

-- SavedVariables
TBCA_ReputationDB = TBCA_ReputationDB or {}
TBCA_ReputationDB.favorites = TBCA_ReputationDB.favorites or {}

-- Session Tracking
local SessionStartRep = {}

-- Constants
local COLOR_FRIENDLY = "|cff1eff00"
local COLOR_HONORED = "|cff0070dd"
local COLOR_REVERED = "|cff9345ff"
local COLOR_EXALTED = "|cffff8000"
local COLOR_RESET = "|r"
local COLOR_GRAY = "|cff808080"
local COLOR_GREEN_PLUS = "|cff00ff00+"

-- Helper: Get Standing Color
local function GetStandingColor(standingID)
    if standingID == 5 then return COLOR_FRIENDLY end -- Friendly
    if standingID == 6 then return COLOR_HONORED end -- Honored
    if standingID == 7 then return COLOR_REVERED end -- Revered
    if standingID == 8 then return COLOR_EXALTED end -- Exalted
    return "|cffffffff" -- Default White
end

-- Helper: Init Session Stats
local function SnapshotReputation()
    local numFactions = GetNumFactions()
    for i = 1, numFactions do
        local name, _, _, _, _, barValue = GetFactionInfo(i)
        if name and not SessionStartRep[name] then
            SessionStartRep[name] = barValue
        end
    end
end

-- Feature 1: Smart Auto-Switch
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")

frame:SetScript("OnEvent", function(self, event, msg)
    if event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        local faction = msg:match("Reputation with (.+) increased")
        
        if faction then
            local numFactions = GetNumFactions()
            for i = 1, numFactions do
                local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(i)
                
                if name == faction then
                    if standingID < 8 then
                        SetWatchedFactionIndex(i)
                        
                        -- Enhanced Chat Output
                        local current = barValue - barMin
                        local max = barMax - barMin
                        local remaining = barMax - barValue
                        local color = GetStandingColor(standingID)
                        local standingLabel = _G["FACTION_STANDING_LABEL"..standingID] or "Unknown"
                        
                        local message = string.format("|cff00ccffTBCA:|r %s%s|r: %d/%d (%s) - %s%d Remaining|r", 
                            color, name, current, max, standingLabel, "|cff808080", remaining)
                        DEFAULT_CHAT_FRAME:AddMessage(message)
                    end
                    break
                end
            end
        end
    end
end)

-- Feature 2: Favorites Tooltip Extension (Custom Position & Data)
local function AddFavoritesToTooltip(tooltip)
    if not TBCA_ReputationDB.favorites or next(TBCA_ReputationDB.favorites) == nil then
        tooltip:AddLine("TBCA Rep: No favorites set.", 1, 0.82, 0)
        tooltip:Show()
        return
    end

    tooltip:AddLine("Reputation Favorites", 1, 0.82, 0)
    tooltip:AddLine(" ")

    local numFactions = GetNumFactions()
    
    for i = 1, numFactions do
        local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(i)
        
        if name and TBCA_ReputationDB.favorites[name] then
            local color = GetStandingColor(standingID)
            local standingLabel = _G["FACTION_STANDING_LABEL"..standingID] or "Unknown"
            
            -- Calculations
            local current = barValue - barMin
            local max = barMax - barMin
            local remaining = barMax - barValue
            
            local percent = 100
            if standingID < 8 and max > 0 then
                percent = math.floor((current / max) * 100)
            end
            
            -- Session Gain
            local gainText = ""
            if SessionStartRep[name] then
                local diff = barValue - SessionStartRep[name]
                if diff > 0 then
                    gainText = string.format(" %s%d|r", COLOR_GREEN_PLUS, diff)
                end
            end
            
            -- Build Text
            -- Format: [Color]Rank[r] Name (Percent%) [Remaining] [SessionGain]
            -- Example: Honored Orgrimmar (31%) - 1250 left +55
            
            local infoText = ""
            if standingID < 8 then
                 infoText = string.format("%s%s|r %s (|cffffffff%d%%|r) %s-%d%s", 
                    color, standingLabel, name, percent, COLOR_GRAY, remaining, gainText)
            else
                 infoText = string.format("%s%s|r %s %s", color, standingLabel, name, gainText)
            end

            tooltip:AddLine(infoText)
        end
    end
    
    tooltip:Show()
end

local function HookMicroButton()
    if CharacterMicroButton then
        -- We override the OnEnter to position it where we want
        CharacterMicroButton:SetScript("OnEnter", function(self)
            -- Anchor: TOP of button, offset up by 150 pixels (approx "midscreen downwards" / "above character")
            GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 150)
            
            -- Optional: Add standard tooltip title if desired, or just our favorites
            -- GameTooltip:SetText(CHARACTER_BUTTON, 1, 1, 1)
            
            AddFavoritesToTooltip(GameTooltip)
        end)
        
        CharacterMicroButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end
end

-- Feature 3: Main List Checkboxes
local checkboxes = {}

local function ToggleFavorite(self)
    local name = self.factionName
    if not name then return end
    
    if self:GetChecked() then
        TBCA_ReputationDB.favorites[name] = true
        print("|cff00ccffTBCA_Rep:|r Added |cffffd700" .. name .. "|r to favorites.")
    else
        TBCA_ReputationDB.favorites[name] = nil
        print("|cff00ccffTBCA_Rep:|r Removed |cffffd700" .. name .. "|r from favorites.")
    end
end

local function UpdateReputationCheckboxes()
    local numFactions = GetNumFactions()
    local factionOffset = FauxScrollFrame_GetOffset(ReputationListScrollFrame)
    
    for i = 1, NUM_FACTIONS_DISPLAYED, 1 do
        local factionIndex = factionOffset + i
        local checkbox = checkboxes[i]
        
        if factionIndex <= numFactions then
            local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)
            
            if name then
                checkbox:Show()
                checkbox.factionName = name
                checkbox:SetChecked(TBCA_ReputationDB.favorites[name] == true)
                
                if isHeader and not hasRep then
                    checkbox:Hide()
                else
                    checkbox:Show()
                end
            else
                checkbox:Hide()
            end
        else
            checkbox:Hide()
        end
    end
end

local function InitializeCheckboxes()
    local count = 15
    if NUM_FACTIONS_DISPLAYED then count = NUM_FACTIONS_DISPLAYED end
    
    for i = 1, count do
        local bar = _G["ReputationBar"..i]
        if bar then
            local check = CreateFrame("CheckButton", "TBCA_RepCheckbox"..i, bar, "UICheckButtonTemplate")
            check:SetPoint("RIGHT", bar, "LEFT", -2, 0)
            check:SetSize(20, 20)
            check:SetScript("OnClick", ToggleFavorite)
            checkboxes[i] = check
        end
    end
    hooksecurefunc("ReputationFrame_Update", UpdateReputationCheckboxes)
end


-- Feature 4: Slash Commands
SLASH_TBCAREP1 = "/rep"
SlashCmdList["TBCAREP"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()
    
    if cmd == "fav" and arg ~= "" then
        local factionName = arg
        if TBCA_ReputationDB.favorites[factionName] then
            TBCA_ReputationDB.favorites[factionName] = nil
            print("|cff00ccffTBCA_Rep:|r Removed |cffffd700" .. factionName .. "|r from favorites.")
        else
            local found = false
            for i=1, GetNumFactions() do
                local name = GetFactionInfo(i)
                if name and name:lower() == factionName:lower() then
                    factionName = name
                    found = true
                    break
                end
            end
            if found then
                TBCA_ReputationDB.favorites[factionName] = true
                print("|cff00ccffTBCA_Rep:|r Added |cffffd700" .. factionName .. "|r to favorites.")
            else
                print("|cff00ccffTBCA_Rep:|r Faction '" .. factionName .. "' not found. Make sure you have discovered it.")
            end
        end
    elseif cmd == "list" then
        print("|cff00ccffTBCA_Rep Favorites:|r")
        local count = 0
        for name, _ in pairs(TBCA_ReputationDB.favorites) do
            print("- " .. name)
            count = count + 1
        end
    else
        print("|cff00ccffTBCA_Rep Usage:|r")
        print("/rep fav <Faction Name> - Toggle favorite")
        print("/rep list - List favorites")
    end
end

-- Initialize logic
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event)
    SnapshotReputation()
    HookMicroButton()
    InitializeCheckboxes()
end)
