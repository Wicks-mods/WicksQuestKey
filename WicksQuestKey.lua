WicksQuestKeyDB = WicksQuestKeyDB or {
    point = "CENTER", relativePoint = "CENTER", x = 0, y = -150,
}

local C_BG     = { 0.05, 0.04, 0.08, 0.97 }
local C_BORDER = { 0.22, 0.18, 0.36, 1 }
local C_GREEN  = { 0.31, 0.78, 0.47, 1 }
local C_HOVER  = { 0.31, 0.78, 0.47, 0.10 }
local C_MOVE   = { 0.64, 0.21, 0.93, 0.20 }

local function NewTexture(parent, layer, c)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(unpack(c))
    return t
end

local function AddBorder(frame, c)
    local t = NewTexture(frame, "BORDER", c); t:SetPoint("TOPLEFT");    t:SetPoint("TOPRIGHT");    t:SetHeight(1)
    local b = NewTexture(frame, "BORDER", c); b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
    local l = NewTexture(frame, "BORDER", c); l:SetPoint("TOPLEFT");    l:SetPoint("BOTTOMLEFT");  l:SetWidth(1)
    local r = NewTexture(frame, "BORDER", c); r:SetPoint("TOPRIGHT");   r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1)
end

local function AddCornerAccents(frame)
    local L, T = 10, 2
    for _, anchor in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local h = NewTexture(frame, "OVERLAY", C_GREEN); h:SetPoint(anchor); h:SetSize(L, T)
        local v = NewTexture(frame, "OVERLAY", C_GREEN); v:SetPoint(anchor); v:SetSize(T, L)
    end
end

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
bindLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
bindLabel:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -3, -3)
bindLabel:SetTextColor(1, 1, 1, 1)
btn.bindLabel = bindLabel

-- Cooldown countdown shown bottom-center of the icon. Driven by a throttled
-- OnUpdate so we don't recompute every frame.
local cdText = btn:CreateFontString(nil, "OVERLAY")
cdText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
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
local UI_MOVES = "|cff8a5cf6Wick's Quest Key|r: Wick's UI places the button. Type /wui move to drag it, and right-click its mover to put it back."

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
        print("|cff8a5cf6Wick's Quest Key|r: cannot change lock during combat.")
        return
    end
    if uiMoves and not state then print(UI_MOVES) return end
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

BINDING_HEADER_WICKSQUESTKEY = "Wicks Quest Key"
-- Binding name has spaces and a colon, so set the display label via bracket syntax.
_G["BINDING_NAME_CLICK WicksQuestKeyButton:LeftButton"] = "Use current quest item"

SLASH_WICKSQUESTKEY1 = "/wqk"
SLASH_WICKSQUESTKEY2 = "/questkey"
SlashCmdList.WICKSQUESTKEY = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "unlock" or msg == "move" then
        if uiMoves then print(UI_MOVES) return end
        SetLocked(false)
        print("|cff8a5cf6Wick's Quest Key|r: unlocked. Left-drag the button to move it.")
        return
    elseif msg == "lock" then
        SetLocked(true)
        print("|cff8a5cf6Wick's Quest Key|r: locked.")
        return
    elseif msg == "reset" then
        if uiMoves then print(UI_MOVES) return end
        WicksQuestKeyDB.point, WicksQuestKeyDB.relativePoint = "CENTER", "CENTER"
        WicksQuestKeyDB.x, WicksQuestKeyDB.y = 0, -150
        ApplyPosition()
        print("|cff8a5cf6Wick's Quest Key|r: position reset.")
        return
    elseif msg == "debug" then
        local k1, k2 = GetBindingKey(QK_BINDING)
        local cur = items[nextIndex]
        print("|cff8a5cf6Wick's Quest Key|r debug:")
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
        print("|cff8a5cf6Wick's Quest Key|r: no usable quest items right now.")
    else
        print(("|cff8a5cf6Wick's Quest Key|r: %d quest item(s) loaded"):format(#items))
        for i, it in ipairs(items) do
            local marker = (i == nextIndex) and "  |cff4fc77b<-- armed|r" or ""
            print(("  %d. %s%s"):format(i, it.name, marker))
        end
    end
    print("Commands: /wqk unlock | lock | reset | debug | fire")
end
