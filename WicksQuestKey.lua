-- Wick's Quest Key
-- One secure button for the quest item you can use right now, drawn in
-- WickCore's chrome so it follows the suite's look and theme.

local ADDON = ...

local Core = WickCore
if not Core then
    -- WickCore is missing or switched off.
    --
    -- The TOC asks for it with OptionalDeps rather than Dependencies on
    -- purpose. A hard dependency makes the client refuse to load this addon
    -- at all, so nothing of ours runs and the player is told nothing beyond
    -- a greyed line in the AddOns list. Loading anyway lets us say what is
    -- wrong and where to get it.
    --
    -- One line for the lot of them, not one per addon: with the whole suite
    -- installed and WickCore switched off, a line each would be a wall.
    local need = _G.WicksNeedCore
    if not need then
        need = {}
        _G.WicksNeedCore = need
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:SetScript("OnEvent", function()
            table.sort(need)
            print(("|cff4FC778Wick's Mods|r: %s %s WickCore, which is not installed or not switched on. It is in the same download as the rest of the suite: |cffD4C8A1wicksmods.com|r")
                :format(table.concat(need, ", "), #need == 1 and "needs" or "need"))
        end)
    end
    need[#need + 1] = "Wick's Quest Key"
    return
end
local Chrome = Core.Chrome
local C = Chrome.Colors

-- No saved variable through WickCore: WicksQuestKeyDB stays as it is.
local A = Core:NewAddon("WicksQuestKey", {
    title   = "Wick's Quest Key",
    version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version"),
})

WicksQuestKeyDB = WicksQuestKeyDB or {
    point = "CENTER", relativePoint = "CENTER", x = 0, y = -150,
}

-- Palette tokens are references into Chrome.Colors, never copies, so a
-- look or theme change repaints the button at once. The unlock tint is
-- the addon's own.
local C_BG     = C.voidBG
local C_BORDER = C.border
local C_GREEN  = C.fel
local C_HOVER  = Chrome:Wash("fel", 0.10)
local C_MOVE   = { 0.64, 0.21, 0.93, 0.20 }

local function NewTexture(parent, layer, c) return Chrome:Texture(parent, layer, c) end
local function AddBorder(frame, c) Chrome:AddBorder(frame, c) end
local function AddCornerAccents(frame) Chrome:AddBrackets(frame) end

-- TBC Anniversary 2.5.5 moved GetItemCooldown into the C_Container namespace.
-- Resolve once at load and fall back to the legacy global so older clients still work.
local GetItemCooldown = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown

local items = {}
local nextIndex = 1

local btn = CreateFrame("Button", "WicksQuestKeyButton", UIParent, "SecureActionButtonTemplate")
btn:SetSize(52, 52)
btn:SetFrameStrata("MEDIUM")
btn:SetClampedToScreen(true)
btn:SetMovable(true)
-- Mirror the working TotemBar pattern: type1=macro, both macrotext attrs set,
-- and registered for AnyUp + AnyDown. The SAB's internal macro path runs the
-- macrotext through a secure C-level processor (NOT the global RunMacroText,
-- which is nil in this client), so this works where type=item didn't.
btn:SetAttribute("type1", "macro")
btn:RegisterForClicks("AnyUp", "AnyDown")
btn:Hide()

local bg = NewTexture(btn, "BACKGROUND", C_BG); bg:SetAllPoints(btn)
AddBorder(btn, C_BORDER)
AddCornerAccents(btn)

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT", 4, -4)
icon:SetPoint("BOTTOMRIGHT", -4, 4)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
btn.icon = icon

local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
count:SetPoint("BOTTOMRIGHT", -3, 3)
btn.count = count

local bindLabel = btn:CreateFontString(nil, "OVERLAY")
Chrome:SetFont(bindLabel, 12, "OUTLINE")
bindLabel:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -3, -3)
bindLabel:SetTextColor(1, 1, 1, 1)
btn.bindLabel = bindLabel

-- Cooldown countdown shown bottom-center of the icon. Driven by a throttled
-- OnUpdate so we don't recompute every frame.
local cdText = btn:CreateFontString(nil, "OVERLAY")
Chrome:SetFont(cdText, 16, "OUTLINE")
cdText:SetPoint("BOTTOM", btn, "BOTTOM", 0, 3)
cdText:SetTextColor(1, 0.92, 0.5, 1)  -- warm yellow, like Blizzard's action bar CD
btn.cdText = cdText

local hover = NewTexture(btn, "HIGHLIGHT", C_HOVER); hover:SetAllPoints(btn)

local moveTint = NewTexture(btn, "OVERLAY", C_MOVE)
moveTint:SetAllPoints(btn)
moveTint:Hide()

btn:SetScript("OnEnter", function(self)
    if #items == 0 then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local cur = items[nextIndex]
    if cur then GameTooltip:SetHyperlink("item:" .. cur.itemId) end
    if #items > 1 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("Quest item %d of %d"):format(nextIndex, #items), 0.31, 0.78, 0.47)
        GameTooltip:AddLine("Right-click to switch to the next item.", 0.42, 0.35, 0.54)
    end
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- With Wick's UI loaded, its movers place the button (/wui move) and this
-- addon's own drag, lock and reset stand down; WickCore keeps the list.
local uiMoves = false
local UI_MOVES = "Wick's UI places the button. Type /wui move to drag it, and right-click its mover to put it back."

local function ApplyPosition()
    if uiMoves then return end
    local db = WicksQuestKeyDB
    btn:ClearAllPoints()
    btn:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
end

local function SavePosition()
    local point, _, relativePoint, x, y = btn:GetPoint(1)
    WicksQuestKeyDB.point = point
    WicksQuestKeyDB.relativePoint = relativePoint
    WicksQuestKeyDB.x = x
    WicksQuestKeyDB.y = y
end

local locked = true
local function SetLocked(state)
    if InCombatLockdown() then
        A:Print("cannot change lock during combat.")
        return
    end
    if uiMoves and not state then A:Print(UI_MOVES) return end
    locked = state
    if locked then
        btn:RegisterForDrag()
        moveTint:Hide()
    else
        btn:RegisterForDrag("LeftButton")
        moveTint:Show()
        if #items == 0 then btn:Show() end
    end
end

btn:SetScript("OnDragStart", function(self) if not locked then self:StartMoving() end end)
btn:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing(); SavePosition() end)

local function RegisterMovable()
    local Chrome = WickCore and WickCore.Chrome
    if not (Chrome and Chrome.RegisterMovable) then return end
    local db = WicksQuestKeyDB
    Chrome:RegisterMovable(btn, {
        key = "questkey", title = "Quest Key", addon = "WicksQuestKey",
        default = ("%s,UIParent,%s,%d,%d"):format(db.point or "CENTER", db.relativePoint or db.point or "CENTER", db.x or 0, db.y or -150),
        onClaim = function()
            uiMoves = true
            if not locked then SetLocked(true) end
        end,
    })
end

local function Arm()
    local cur = items[nextIndex]
    if cur then
        if not InCombatLockdown() then
            local macro = "/use " .. (cur.name or tostring(cur.itemId))
            -- Set BOTH macrotext and macrotext1 (same as the TotemBar pattern).
            -- type1=macro reads macrotext1 first, falls back to macrotext on
            -- some clients but not all — setting both covers every variant.
            btn:SetAttribute("macrotext", macro)
            btn:SetAttribute("macrotext1", macro)
        end
        btn.icon:SetTexture(cur.icon)
        btn.icon:Show()
        if not InCombatLockdown() then btn:Show() end
    else
        if not InCombatLockdown() then
            btn:SetAttribute("macrotext", nil)
            btn:SetAttribute("macrotext1", nil)
            if locked then btn:Hide() end
        end
        btn.icon:Hide()
    end
end

local function UpdateCount()
    local cur = items[nextIndex]
    if cur then
        local n = GetItemCount(cur.itemId) or 0
        btn.count:SetText(n > 1 and tostring(n) or "")
    else
        btn.count:SetText("")
    end
end

-- Cooldown text: "Xm" for >=60s, whole seconds for >=10s, one decimal under 10s.
local function FormatCD(seconds)
    if seconds <= 0 then return "" end
    if seconds >= 60 then return ("%dm"):format(math.ceil(seconds / 60)) end
    if seconds >= 10 then return ("%d"):format(math.ceil(seconds)) end
    return ("%.1f"):format(seconds)
end

-- Recompute and write the CD text from GetItemCooldown for the armed item.
-- Called from the throttled OnUpdate below and on every Arm().
local function UpdateCD()
    local cur = items[nextIndex]
    if not cur then btn.cdText:SetText(""); return end
    local start, duration = GetItemCooldown(cur.itemId)
    if not start or start == 0 or not duration or duration <= 1.5 then
        -- duration <= GCD: not a real cooldown, hide the text
        btn.cdText:SetText("")
        return
    end
    local remaining = (start + duration) - GetTime()
    if remaining <= 0 then btn.cdText:SetText(""); return end
    btn.cdText:SetText(FormatCD(remaining))
end

-- Throttle the CD recompute to ~10Hz so the text updates smoothly without
-- burning CPU on every frame.
local cdElapsed = 0
btn:SetScript("OnUpdate", function(self, dt)
    cdElapsed = cdElapsed + dt
    if cdElapsed < 0.1 then return end
    cdElapsed = 0
    UpdateCD()
end)

local function ShortBind(key)
    if not key or key == "" then return "" end
    return (key:upper()
        :gsub("ALT%-", "a")
        :gsub("CTRL%-", "c")
        :gsub("SHIFT%-", "s")
        :gsub("NUMPAD", "n")
        :gsub("BUTTON1", "M1")
        :gsub("BUTTON2", "M2")
        :gsub("BUTTON3", "M3")
        :gsub("MOUSEWHEELUP", "MwU")
        :gsub("MOUSEWHEELDOWN", "MwD"))
end

-- Bindings.xml uses the native "CLICK WicksQuestKeyButton:LeftButton" binding
-- name, which Blizzard interprets as a real secure click on the button. So we
-- only need to look up the bound key for the on-button label here. No
-- SetOverrideBindingClick needed.
local QK_BINDING = "CLICK WicksQuestKeyButton:LeftButton"

local function UpdateBindLabel()
    local key = GetBindingKey(QK_BINDING)
    btn.bindLabel:SetText(ShortBind(key))
end

local function Scan()
    if InCombatLockdown() then return end
    wipe(items)
    local seen = {}
    for i = 1, GetNumQuestLogEntries() do
        local _, _, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader then
            local link, iconTex = GetQuestLogSpecialItemInfo(i)
            local itemId = link and tonumber(link:match("item:(%d+)"))
            if itemId and not seen[itemId] then
                seen[itemId] = true
                local cachedName, _, _, _, _, _, _, _, _, cachedIcon = GetItemInfo(itemId)
                items[#items + 1] = {
                    itemId = itemId,
                    name   = cachedName or link:match("%[(.-)%]") or ("item:" .. itemId),
                    icon   = iconTex or cachedIcon or 134400,
                }
            end
        end
    end
    if nextIndex > #items or nextIndex < 1 then nextIndex = 1 end
    Arm()
    UpdateCount()
end

-- HookScript instead of SetScript: SecureActionButtonTemplate's built-in OnClick
-- is the code path that resolves type1=macro / type1=item and fires the action.
-- Replacing it with SetScript silently stopped the action from running.
-- HookScript appends our handler so the secure click still happens.
-- HookScript so Blizzard's secure OnClick handler still runs and fires the
-- macrotext for left-click. Our hook only handles the right-click cycle.
-- AnyUp+AnyDown registration makes OnClick fire twice per click (down + up),
-- so filter to `down` only or the cycle would advance twice.
btn:HookScript("OnClick", function(self, button, down)
    if button == "RightButton" and down and not InCombatLockdown() and #items > 1 then
        nextIndex = (nextIndex % #items) + 1
        Arm()
        UpdateCount()
        UpdateCD()
    end
end)

-- Left-click / keybind use the current item but DO NOT advance the cycle, so
-- you can spam the bind on a quest that needs the item used several times.
-- Right-click is the only way to advance to the next item.
btn:HookScript("PostClick", function(self, button, down)
    if button == "LeftButton" and down and not InCombatLockdown() then
        UpdateCount()
        UpdateCD()
    end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:RegisterEvent("UPDATE_BINDINGS")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then RegisterMovable(); ApplyPosition(); UpdateBindLabel() end
    if event == "UPDATE_BINDINGS" then UpdateBindLabel(); return end
    if event == "BAG_UPDATE_DELAYED" then UpdateCount(); return end
    Scan()
end)

-- Put the button back where a fresh install has it.
local function ResetPosition()
    WicksQuestKeyDB.point, WicksQuestKeyDB.relativePoint = "CENTER", "CENTER"
    WicksQuestKeyDB.x, WicksQuestKeyDB.y = 0, -150
    ApplyPosition()
    A:Print("position reset.")
end

-- The page under Wick's Mods in the game's Options, and a line in the
-- suite's launcher that opens it.
function A:OnEnable()
    self:RegisterOptions(function(body)
        local O = Core.Options
        local y = 0
        y = O:Note(body, "One button for the quest item you can use right now, armed from the quest log. Left-click it or press its key to use the item; right-click cycles when more than one quest has an item. The key is set under Key Bindings, Wick's Quest Key.", y)
        y = O:Heading(body, "Place", y)
        if uiMoves then
            y = O:Note(body, UI_MOVES, y)
        else
            y = O:Check(body, "Unlocked, drag it to move it", function() return not locked end, function(v) SetLocked(not v) end, y)
            y = O:Button(body, "Put it back in the middle", ResetPosition, y, 200)
        end
    end)
    self:RegisterLauncher({
        onClick = function() Core.Options:Open("WicksQuestKey") end,
        tooltip = function(tt)
            tt:AddLine(Chrome:TitleMarkup("Wick's Quest Key"))
            tt:AddLine("The quest item button. Click for its settings.", 1, 1, 1)
        end,
    })
end

BINDING_HEADER_WICKSQUESTKEY = "Wicks Quest Key"
-- Binding name has spaces and a colon, so set the display label via bracket syntax.
_G["BINDING_NAME_CLICK WicksQuestKeyButton:LeftButton"] = "Use current quest item"

SLASH_WICKSQUESTKEY1 = "/wqk"
SLASH_WICKSQUESTKEY2 = "/questkey"
SlashCmdList.WICKSQUESTKEY = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "unlock" or msg == "move" then
        if uiMoves then A:Print(UI_MOVES) return end
        SetLocked(false)
        A:Print("unlocked. Left-drag the button to move it.")
        return
    elseif msg == "lock" then
        SetLocked(true)
        A:Print("locked.")
        return
    elseif msg == "reset" then
        if uiMoves then A:Print(UI_MOVES) return end
        ResetPosition()
        return
    elseif msg == "debug" then
        local k1, k2 = GetBindingKey(QK_BINDING)
        local cur = items[nextIndex]
        A:Print("debug:")
        print(("  bind keys: %s | %s"):format(k1 or "(none)", k2 or "(none)"))
        print(("  items loaded: %d  armed index: %d"):format(#items, nextIndex))
        if cur then
            print(("  armed item: %s (id %d)"):format(cur.name, cur.itemId))
            print(("  type1 attr: %s   macrotext: %s"):format(
                tostring(btn:GetAttribute("type1")), tostring(btn:GetAttribute("macrotext"))))
            print(("  macrotext1: %s"):format(tostring(btn:GetAttribute("macrotext1"))))
        end
        print(("  button visible: %s   in combat: %s"):format(
            tostring(btn:IsShown()), tostring(InCombatLockdown())))
        return
    end
    if #items == 0 then
        A:Print("no usable quest items right now.")
    else
        A:Print(("%d quest item(s) loaded"):format(#items))
        for i, it in ipairs(items) do
            local marker = (i == nextIndex) and ("  " .. Chrome:Esc("fel") .. "<-- armed|r") or ""
            print(("  %d. %s%s"):format(i, it.name, marker))
        end
    end
    print("Commands: /wqk unlock | lock | reset | debug | fire")
end
