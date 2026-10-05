-- ActionTrail - independent WoW Forever addon
-- Copyright (c) 2026 Zabratooth
-- Released under the MIT License; see LICENSE for details.

local ADDON = ...
local VERSION = "1.5.12"

local localeDefault = (GetLocale and GetLocale() == "deDE") and "de" or "en"

local STRINGS = {
    de = {
        wand = "Wand Shoot anzeigen",
        autoshot = "Auto Shot anzeigen",
        melee = "Normale Melee-Attacks anzeigen",
        minimap = "Minimap-Button anzeigen",
        historyIcons = "Anzahl Historien-Icons",
        iconSize = "Icon-Größe",
        combatOnly = "Nur im Kampf sichtbar",
        fade = "Icons langsam verblassen lassen",
        fadeSeconds = "Verblassdauer (Sekunden)",
        gseTitle = "GSE-Debug",
        gseTriggers = "GSE-Auslösungen anzeigen",
        clickNumber = "Laufende Klicknummer anzeigen",
        markEmpty = "Leere Auslösung markieren",
        latency = "Zeit bis zum Cast anzeigen",
        gseCombatOnly = "GSE-Debug nur im Kampf",
        debugHistory = "Debug-Historie",
        showEmpty = "Kein Cast anzeigen",
        clearDebug = "GSE-Debug leeren",
        unlock = "Position entsperren",
        lock = "Position sperren",
        reset = "Zurücksetzen",
        language = "Sprache",
        langChanged = "Sprache geändert – UI wird neu geladen.",
        tipLeft = "Linksklick: Einstellungen",
        tipRight = "Rechtsklick: GSE-Debug an/aus",
        tipDrag = "Ziehen: Position am Minimap-Rand",
        debugOn = "an",
        debugOff = "aus",
        unlocked = "entsperrt",
        locked = "gesperrt",
        resetDone = "zurückgesetzt",
        menuWord = "Menü",
        hideErrors = "Aktionsfehler ausblenden",
        showGSEFrameInfo = "Technische GSE-Infos anzeigen",
        errorsHidden = "Aktions-Fehlermeldungen werden ausgeblendet.",
        errorsShown = "Aktions-Fehlermeldungen werden angezeigt.",
    },
    en = {
        wand = "Show Wand Shoot",
        autoshot = "Show Auto Shot",
        melee = "Show normal melee attacks",
        minimap = "Show minimap button",
        historyIcons = "Number of history icons",
        iconSize = "Icon size",
        combatOnly = "Only visible in combat",
        fade = "Slowly fade icons",
        fadeSeconds = "Fade duration (seconds)",
        gseTitle = "GSE Debug",
        gseTriggers = "Show GSE triggers",
        clickNumber = "Show running click number",
        markEmpty = "Mark empty trigger",
        latency = "Show time to cast",
        gseCombatOnly = "GSE debug only in combat",
        debugHistory = "Debug history",
        showEmpty = "Show no-cast entries",
        clearDebug = "Clear GSE debug",
        unlock = "Unlock position",
        lock = "Lock position",
        reset = "Reset",
        language = "Language",
        langChanged = "Language changed – reloading UI.",
        tipLeft = "Left-click: Settings",
        tipRight = "Right-click: Toggle GSE debug",
        tipDrag = "Drag: Move around minimap edge",
        debugOn = "on",
        debugOff = "off",
        unlocked = "unlocked",
        locked = "locked",
        resetDone = "reset",
        menuWord = "Menu",
        hideErrors = "Hide action errors",
        showGSEFrameInfo = "Show technical GSE info",
        errorsHidden = "Action error messages are hidden.",
        errorsShown = "Action error messages are shown.",
    },
}

local function T(key)
    local lang = (ActionTrailDB and ActionTrailDB.language) or localeDefault
    local tbl = STRINGS[lang] or STRINGS.en
    return tbl[key] or STRINGS.en[key] or key
end

local defaults = {
    language = localeDefault,
    x = 0,
    y = -120,
    iconSize = 32,
    spacing = 4,
    maxIcons = 5,
    opacity = 1,
    locked = true,
    showWand = false,
    showAutoShot = false,
    showMelee = false,
    onlyInCombat = false,
    fadeEnabled = false,
    fadeSeconds = 8,
    gseDebug = false,
    gseClickNumbers = true,
    gseMarkEmpty = true,
    gseShowEmpty = false,
    gseLatency = true,
    gseDebugCombatOnly = false,
    gseDebugRows = 8,
    showMinimapButton = true,
    minimapAngle = 220,
    hideActionErrors = false,
    showGSEFrameInfo = false,
}

local AUTO_SHOT = 75
local WAND_SHOOT = 5019
local MELEE_ATTACK = 6603

-- Auto-repeat spells (wand Shoot / Auto Shot) do not reliably emit the normal
-- UNIT_SPELLCAST_* stream in Forever. Track start/stop separately so the
-- activation is still visible in the trail. This records the start of the
-- auto-repeat, not every individual ranged swing.
local autoRepeatActive = false
local autoRepeatSpellID = nil
local shootDebugTargetGUID = nil
local shootTrailTargetGUID = nil
local CANCEL_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"
local UNKNOWN_ICON = 134400
local HIDDEN_HELPER_ICON = 136243
local REQUEST_TTL = 5
local CAST_TTL = 10
local QUIET_AFTER_LOGIN = 0.5

local root = CreateFrame("Frame", "ActionTrailFrame", UIParent, "BackdropTemplate")
root:SetFrameStrata("HIGH")
root:SetMovable(true)
root:SetClampedToScreen(true)
root:RegisterForDrag("LeftButton")

local visible = {}
local fadingOut = {}
local recycled = {}
local SLIDE_SPEED = 18
local OVERFLOW_FADE = 0.40
local serial = 0
local activeCasts = {}
local recentRequestsByGUID = {}
local recentRequestsBySpell = {}
local suppressUntil = 0
local requestEventAvailable = false

-- GSE debug state. We do not modify GSE or its secure attributes; we only attach
-- ordinary post-click hooks to executor buttons and correlate those clicks with
-- the player's subsequent UNIT_SPELLCAST_SENT requests.
local gseHooked = setmetatable({}, { __mode = "k" })
local gsePending = {}
local gseHistory = {}
local gseClickSerial = 0
local GSE_MATCH_WINDOW = 0.45
local GSE_EMPTY_DELAY = 0.30
local debugFrame
local debugLines = {}
local minimapButton
local createMinimapButton
local applyMinimapVisibility
local toggleMenu

local function secret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, v)
    return (not ok) or result == true
end

local function spellInfo(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then return info.name, info.iconID end
    end
    if GetSpellInfo then
        local name, _, icon = GetSpellInfo(id)
        return name, icon
    end
end

local function textureFor(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    if GetSpellTexture then return GetSpellTexture(id) end
end

local function mergeDefaults()
    ActionTrailDB = ActionTrailDB or {}
    for k, v in pairs(defaults) do
        if ActionTrailDB[k] == nil then ActionTrailDB[k] = v end
    end
end

local function blocked(id)
    if id == WAND_SHOOT then return not ActionTrailDB.showWand end
    if id == AUTO_SHOT then return not ActionTrailDB.showAutoShot end
    if id == MELEE_ATTACK then return not ActionTrailDB.showMelee end
    return false
end

local function debugShouldShow()
    if not ActionTrailDB or not ActionTrailDB.gseDebug then return false end
    if ActionTrailDB.gseDebugCombatOnly then
        return UnitAffectingCombat("player") == true
    end
    return true
end

local function formatSpellName(spellID)
    if not spellID then return nil end
    -- Forever does not always resolve the wand auto-repeat like a normal cast.
    -- Give spell 5019 a stable diagnostic label so GSE debug can show exactly
    -- what started the wand phase even when the regular spell stream is sparse.
    if spellID == WAND_SHOOT then return "Shoot [5019]" end
    local name = spellInfo(spellID)
    return name or ("Spell " .. tostring(spellID))
end

local function refreshDebugFrame()
    if not debugFrame or not ActionTrailDB then return end
    if not debugShouldShow() then
        debugFrame:Hide()
        return
    end

    local rows = math.max(3, math.min(15, tonumber(ActionTrailDB.gseDebugRows) or 8))
    local lineHeight = 15
    debugFrame:SetSize(math.max(360, root:GetWidth()), rows * lineHeight + 10)
    debugFrame:ClearAllPoints()
    debugFrame:SetPoint("TOP", root, "BOTTOM", 0, -8)
    debugFrame:Show()

    local displayHistory = {}
    for _, rec in ipairs(gseHistory) do
        if ActionTrailDB.gseShowEmpty or not rec.empty then
            displayHistory[#displayHistory + 1] = rec
            if #displayHistory >= rows then break end
        end
    end

    for i = 1, 15 do
        local fs = debugLines[i]
        if i <= rows then
            local rec = displayHistory[i]
            if rec then
                local parts = {}
                if ActionTrailDB.gseClickNumbers then
                    parts[#parts+1] = ("G%d"):format(rec.number)
                else
                    parts[#parts+1] = "G"
                end
                if rec.modifier and rec.modifier ~= "" then
                    parts[#parts+1] = ("[%s]"):format(rec.modifier)
                end
                if ActionTrailDB.showGSEFrameInfo and rec.sequence and rec.sequence ~= "" then
                    parts[#parts+1] = rec.sequence
                end
                if rec.step then
                    parts[#parts+1] = ("step %s"):format(tostring(rec.step))
                end
                local spellText
                if rec.spellID then
                    spellText = formatSpellName(rec.spellID)
                    if ActionTrailDB.gseLatency and rec.deltaMS then
                        spellText = spellText .. (" +%dms"):format(rec.deltaMS)
                    end
                elseif rec.empty then
                    spellText = ActionTrailDB.gseMarkEmpty and "— kein Cast" or ""
                else
                    spellText = "…"
                end
                if spellText ~= "" then parts[#parts+1] = "→ " .. spellText end
                fs:SetText(table.concat(parts, "  "))
                fs:Show()
            else
                fs:SetText("")
                fs:Hide()
            end
        else
            fs:Hide()
        end
    end
end

local function ensureDebugFrame()
    if debugFrame then return end
    debugFrame = CreateFrame("Frame", "ActionTrailGSEDebugFrame", UIParent, "BackdropTemplate")
    debugFrame:SetFrameStrata("HIGH")
    debugFrame:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Buttons/WHITE8X8", edgeSize=1})
    debugFrame:SetBackdropColor(0, 0, 0, 0.52)
    debugFrame:SetBackdropBorderColor(0.2, 0.8, 1, 0.45)
    debugFrame:EnableMouse(false)
    for i = 1, 15 do
        local fs = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 6, -5 - (i - 1) * 15)
        fs:SetJustifyH("LEFT")
        fs:SetWidth(620)
        fs:SetText("")
        fs:Hide()
        debugLines[i] = fs
    end
    debugFrame:Hide()
end

local function trimGSEHistory()
    local rows = math.max(3, math.min(15, tonumber(ActionTrailDB and ActionTrailDB.gseDebugRows) or 8))
    -- When empty triggers are hidden, retain enough raw clicks for the requested
    -- number of successful casts to remain visible even with fast key spam.
    local keep = (ActionTrailDB and ActionTrailDB.gseShowEmpty) and rows or math.max(120, rows * 30)
    while #gseHistory > keep do table.remove(gseHistory) end
end

local function noteGSEClick(frame)
    if not ActionTrailDB or not ActionTrailDB.gseDebug then return end
    if ActionTrailDB.gseDebugCombatOnly and UnitAffectingCombat("player") ~= true then return end

    gseClickSerial = gseClickSerial + 1
    local now = GetTime()
    local mods = {}
    if IsShiftKeyDown and IsShiftKeyDown() then mods[#mods + 1] = "SHIFT" end
    if IsAltKeyDown and IsAltKeyDown() then mods[#mods + 1] = "ALT" end
    if IsControlKeyDown and IsControlKeyDown() then mods[#mods + 1] = "CTRL" end

    local rec = {
        number = gseClickSerial,
        time = now,
        frame = frame,
        modifier = (#mods > 0) and table.concat(mods, "+") or nil,
        sequence = (frame and frame.GetName and frame:GetName()) or "GSE",
        step = (frame and frame.GetAttribute and frame:GetAttribute("step")) or nil,
        iteration = (frame and frame.GetAttribute and frame:GetAttribute("iteration")) or nil,
        matched = false,
        empty = false,
    }
    table.insert(gseHistory, 1, rec)
    table.insert(gsePending, rec)
    trimGSEHistory()
    refreshDebugFrame()

    C_Timer.After(GSE_EMPTY_DELAY, function()
        if not rec.matched then
            rec.empty = true
            -- When empty triggers are hidden, discard the row entirely instead
            -- of letting thousands of spam clicks evict the useful cast rows.
            if ActionTrailDB and not ActionTrailDB.gseShowEmpty then
                for i = #gseHistory, 1, -1 do
                    if gseHistory[i] == rec then
                        table.remove(gseHistory, i)
                        break
                    end
                end
            end
            refreshDebugFrame()
        end
    end)
end

local function matchGSESpell(spellID)
    if not ActionTrailDB or not ActionTrailDB.gseDebug or not spellID or secret(spellID) then return end
    local now = GetTime()
    for i = #gsePending, 1, -1 do
        local rec = gsePending[i]
        local age = now - rec.time
        if rec.matched or age > GSE_MATCH_WINDOW then
            table.remove(gsePending, i)
        elseif age >= 0 then
            rec.matched = true
            rec.empty = false
            rec.spellID = spellID
            rec.deltaMS = math.floor(age * 1000 + 0.5)
            table.remove(gsePending, i)
            refreshDebugFrame()
            return
        end
    end
end

local function hookGSEExecutor(frame)
    if not frame or gseHooked[frame] or not frame.HookScript then return false end
    local ok = pcall(function()
        frame:HookScript("OnClick", function(self)
            -- HookScript is deliberately non-secure: we observe only, and never
            -- write attributes on GSE's protected executor.
            noteGSEClick(self)
        end)
    end)
    if ok then
        gseHooked[frame] = true
        gseHookCount = gseHookCount + 1
    end
    return ok
end

local function scanGSEExecutors()
    if not ActionTrailDB or not ActionTrailDB.gseDebug then return end

    -- Method 1: GSE action-bar overrides expose their executor through the
    -- clickbutton attribute. This works without depending on GSE's Lua globals.
    local f = EnumerateFrames and EnumerateFrames() or nil
    local safety = 0
    while f and safety < 10000 do
        safety = safety + 1
        if f.GetAttribute then
            local ok, marker = pcall(f.GetAttribute, f, "gse-button")
            if ok and marker then
                local ok2, executor = pcall(f.GetAttribute, f, "clickbutton")
                if ok2 and executor and executor.HookScript then hookGSEExecutor(executor) end
            end

            -- Method 2: direct GSE binds can click the executor without an
            -- action-bar override. Older GSE builds exposed both step and ms,
            -- while newer/alternate executor frames may expose only step.
            local okStep, step = pcall(f.GetAttribute, f, "step")
            local okMS, ms = pcall(f.GetAttribute, f, "ms")
            local frameName = (f.GetName and f:GetName()) or ""
            local looksLikeGSE = frameName:match("^local%-") or frameName:lower():find("gse", 1, true)
            if okStep and step ~= nil and ((okMS and ms ~= nil) or looksLikeGSE) then
                hookGSEExecutor(f)
            end

            -- Method 3: some action buttons expose only a clickbutton target.
            -- Follow that target when it itself looks like a GSE executor.
            local okClick, clickTarget = pcall(f.GetAttribute, f, "clickbutton")
            if okClick and clickTarget and clickTarget.HookScript then
                local targetName = (clickTarget.GetName and clickTarget:GetName()) or ""
                local okTargetStep, targetStep = true, nil
                if clickTarget.GetAttribute then
                    okTargetStep, targetStep = pcall(clickTarget.GetAttribute, clickTarget, "step")
                end
                if targetName:match("^local%-") or targetName:lower():find("gse", 1, true) or (okTargetStep and targetStep ~= nil) then
                    hookGSEExecutor(clickTarget)
                end
            end
        end
        f = EnumerateFrames(f)
    end
end

local function shouldShowRoot()
    if not ActionTrailDB then return true end
    if ActionTrailDB.locked == false then return true end
    if ActionTrailDB.onlyInCombat then
        return UnitAffectingCombat("player") == true
    end
    return true
end

local function applyVisibility()
    if shouldShowRoot() then root:Show() else root:Hide() end
    if ActionTrailDB then
        ensureDebugFrame()
        createMinimapButton()
        applyMinimapVisibility()
        refreshDebugFrame()
    end
end

local function placeItem(item)
    item.frame:ClearAllPoints()
    item.frame:SetPoint("RIGHT", root, "RIGHT", item.x or 0, 0)
end

local function applyLayout()
    local d = ActionTrailDB
    local step = d.iconSize + d.spacing
    root:SetSize(d.maxIcons * d.iconSize + math.max(0, d.maxIcons - 1) * d.spacing, d.iconSize)
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "CENTER", d.x, d.y)
    for i, item in ipairs(visible) do
        item.frame:SetSize(d.iconSize, d.iconSize)
        item.targetX = -((i - 1) * step)
        if item.x == nil then item.x = item.targetX end
        placeItem(item)
        item.frame:SetAlpha(d.opacity)
    end
    for _, item in ipairs(fadingOut) do
        item.frame:SetSize(d.iconSize, d.iconSize)
        placeItem(item)
    end
    applyVisibility()
    if ActionTrailDB then refreshDebugFrame() end
end

local function applyLock()
    local unlocked = not ActionTrailDB.locked
    root:EnableMouse(unlocked)
    if unlocked then
        root:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Buttons/WHITE8X8", edgeSize=1})
        root:SetBackdropColor(0,0,0,0.15)
        root:SetBackdropBorderColor(0.2,0.8,1,0.9)
    else
        root:SetBackdrop(nil)
    end
end

root:SetScript("OnDragStart", function(self)
    if ActionTrailDB and not ActionTrailDB.locked then self:StartMoving() end
end)

root:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ActionTrailDB.x = math.floor((x - ux) + 0.5)
    ActionTrailDB.y = math.floor((y - uy) + 0.5)
    applyLayout()
end)

local function obtainIcon()
    local item = table.remove(recycled)
    if not item then
        local f = CreateFrame("Frame", nil, root)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0,0,0,0.8)

        local tex = f:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", -1, 1)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local cross = f:CreateTexture(nil, "OVERLAY")
        cross:SetAllPoints()
        cross:SetTexture(CANCEL_TEXTURE)
        cross:Hide()

        item = {frame=f, texture=tex, cross=cross}
    end
    item.cross:Hide()
    item.frame:Show()
    return item
end

local function recycle(item)
    item.frame:Hide()
    item.frame:ClearAllPoints()
    item.cross:Hide()
    item.key = nil
    item.x = nil
    item.targetX = nil
    item.overflowStarted = nil
    table.insert(recycled, item)
end

local function sendOverflow(item)
    local step = ActionTrailDB.iconSize + ActionTrailDB.spacing
    item.overflowStarted = GetTime()
    item.targetX = -(ActionTrailDB.maxIcons * step)
    table.insert(fadingOut, item)
end

local function trim()
    while #visible > ActionTrailDB.maxIcons do
        sendOverflow(table.remove(visible))
    end
end

local function showAction(spellID, castGUID)
    if not spellID or blocked(spellID) then return nil end
    local name, icon = spellInfo(spellID)
    if not name then return nil end
    if icon == HIDDEN_HELPER_ICON then return nil end
    if not icon then icon = textureFor(spellID) end
    if secret(icon) then
        -- safe to pass through to SetTexture
    elseif not icon then
        icon = UNKNOWN_ICON
    end

    local item = obtainIcon()
    local ok = pcall(item.texture.SetTexture, item.texture, icon)
    if not ok then recycle(item); return nil end

    serial = serial + 1
    item.key = serial
    item.spellID = spellID
    item.born = GetTime()
    item.castGUID = castGUID
    item.x = ActionTrailDB.iconSize + ActionTrailDB.spacing
    item.targetX = 0
    table.insert(visible, 1, item)
    trim()
    applyLayout()
    return item
end

local function markCancelled(record, state)
    if record and record.item and record.item.key == record.key then
        record.item.cross:SetShown(state)
    end
end

local function cleanupRequests(now)
    for k, t in pairs(recentRequestsByGUID) do
        if now - t > CAST_TTL then recentRequestsByGUID[k] = nil end
    end
    for k, t in pairs(recentRequestsBySpell) do
        if now - t > REQUEST_TTL then recentRequestsBySpell[k] = nil end
    end
end

local function requested(castGUID, spellID, now)
    if not requestEventAvailable then return true end
    if castGUID and recentRequestsByGUID[castGUID] then return true end
    local t = recentRequestsBySpell[spellID]
    return t and (now - t <= REQUEST_TTL) or false
end

local function noteRequest(castGUID, spellID)
    local now = GetTime()
    cleanupRequests(now)

    -- GSE can keep sending Shoot/Auto Shot requests on every spammed click while
    -- the auto-repeat is already running. Those are not new casts. Match only
    -- the request that starts the auto-repeat phase; suppress the rest until a
    -- STOP_AUTOREPEAT_SPELL event resets the state.
    local repeatedAutoRequest = autoRepeatActive and autoRepeatSpellID and spellID == autoRepeatSpellID
    local suppressShootDebug = false
    if spellID == WAND_SHOOT then
        local targetGUID = UnitGUID("target") or "__notarget__"
        if shootDebugTargetGUID == targetGUID then
            suppressShootDebug = true
        else
            shootDebugTargetGUID = targetGUID
        end
    end
    if not repeatedAutoRequest and not suppressShootDebug then
        matchGSESpell(spellID)
    end

    if castGUID and not secret(castGUID) then recentRequestsByGUID[castGUID] = now end
    if spellID and not secret(spellID) then recentRequestsBySpell[spellID] = now end
end

local function handleSpellEvent(event, castGUID, spellID)
    -- Wand Shoot / Auto Shot are auto-repeat actions. Once their auto-repeat is
    -- active, START_AUTOREPEAT_SPELL is the authoritative trail entry. Ignore
    -- any repeated UNIT_SPELLCAST_* notifications for the same spell so the
    -- history does not fill with one icon per ranged swing.
    if autoRepeatActive and autoRepeatSpellID and spellID == autoRepeatSpellID then
        return
    end

    if not spellID or secret(spellID) or secret(castGUID) then
        if (event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_START") and spellID then
            local tex = textureFor(spellID)
            if tex then showAction(spellID, castGUID) end
        end
        return
    end

    if blocked(spellID) then return end

    local now = GetTime()
    local wasRequested = requested(castGUID, spellID, now)

    if event == "UNIT_SPELLCAST_START" then
        if wasRequested and castGUID then
            local item = showAction(spellID, castGUID)
            if item then
                activeCasts[castGUID] = {item=item, key=item.key, spellID=spellID, started=now, channel=false, done=false}
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if wasRequested then
            local item = showAction(spellID, castGUID)
            if castGUID and item then
                activeCasts[castGUID] = {item=item, key=item.key, spellID=spellID, started=now, channel=true, done=false}
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local rec = castGUID and activeCasts[castGUID]
        if rec then
            rec.done = true
            markCancelled(rec, false)
            if not rec.channel then activeCasts[castGUID] = nil end
        elseif wasRequested then
            showAction(spellID, castGUID)
        end
        return
    end

    if event == "UNIT_SPELLCAST_STOP" then
        local rec = castGUID and activeCasts[castGUID]
        if rec and not rec.done and not rec.channel then
            markCancelled(rec, true)
            activeCasts[castGUID] = nil
        end
        return
    end

    if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if castGUID then activeCasts[castGUID] = nil end
    end
end

local function detectAutoRepeatSpellID()
    local _, class = UnitClass("player")
    if class == "HUNTER" then return AUTO_SHOT end
    -- On WoW Forever START_AUTOREPEAT_SPELL does not reliably provide a spell
    -- payload for wanding. For non-hunters, the auto-repeat action we care about
    -- is the generic wand Shoot spell (5019).
    return WAND_SHOOT
end

local function handleAutoRepeatStart()
    if not ActionTrailDB or GetTime() < suppressUntil then return end
    local spellID = detectAutoRepeatSpellID()
    if not spellID then return end

    -- Some clients can emit START_AUTOREPEAT_SPELL more than once while the
    -- same wand/auto-shot remains active. Treat that as one continuous action.
    if autoRepeatActive and autoRepeatSpellID == spellID then
        return
    end

    autoRepeatActive = true
    autoRepeatSpellID = spellID

    -- If UNIT_SPELLCAST_SENT already reported this exact Shoot/Auto Shot just
    -- before START_AUTOREPEAT_SPELL, noteRequest() has already matched the GSE
    -- click. Only use START_AUTOREPEAT_SPELL as a fallback when no recent spell
    -- request exists, avoiding a second Shoot row for the same wand start.
    local now = GetTime()
    local targetGUID = UnitGUID("target") or "__notarget__"
    local lastRequest = recentRequestsBySpell[spellID]

    -- Forever can emit STOP/START for every individual wand swing. For Shoot,
    -- dedupe by target instead of by the nominal auto-repeat phase. That gives
    -- us one diagnostic row and one trail icon per mob, even if the client
    -- repeatedly tears down and restarts auto-repeat internally.
    if spellID == WAND_SHOOT then
        if shootDebugTargetGUID ~= targetGUID then
            shootDebugTargetGUID = targetGUID
            if not lastRequest or (now - lastRequest) > 0.30 then
                matchGSESpell(spellID)
            end
        end
        if not blocked(spellID) and shootTrailTargetGUID ~= targetGUID then
            shootTrailTargetGUID = targetGUID
            showAction(spellID, "autorepeat:" .. tostring(now))
        end
        return
    end

    if not lastRequest or (now - lastRequest) > 0.30 then
        matchGSESpell(spellID)
    end
    if not blocked(spellID) then
        showAction(spellID, "autorepeat:" .. tostring(now))
    end
end

local function handleAutoRepeatStop()
    autoRepeatActive = false
    autoRepeatSpellID = nil
end

local function timeFadeFactor(item, now)
    if not ActionTrailDB or not ActionTrailDB.fadeEnabled then return 1 end
    local duration = math.max(1, tonumber(ActionTrailDB.fadeSeconds) or 8)
    local age = now - (item.born or now)
    return math.max(0, 1 - (age / duration))
end

local function updateFade()
    if not ActionTrailDB then return end
    local now = GetTime()
    local relayout = false
    for i = #visible, 1, -1 do
        local item = visible[i]
        local factor = timeFadeFactor(item, now)
        if factor <= 0 then
            table.remove(visible, i)
            recycle(item)
            relayout = true
        else
            item.frame:SetAlpha(ActionTrailDB.opacity * factor)
        end
    end
    if relayout then applyLayout() end
end

local function updateMotion(elapsed)
    if not ActionTrailDB then return end
    local now = GetTime()
    local ease = math.min(1, elapsed * SLIDE_SPEED)

    for _, item in ipairs(visible) do
        local tx = item.targetX or 0
        item.x = (item.x or tx) + (tx - (item.x or tx)) * ease
        if math.abs(tx - item.x) < 0.05 then item.x = tx end
        placeItem(item)
    end

    for i = #fadingOut, 1, -1 do
        local item = fadingOut[i]
        local tx = item.targetX or item.x or 0
        item.x = (item.x or tx) + (tx - (item.x or tx)) * ease
        local elapsedFade = now - (item.overflowStarted or now)
        local factor = math.max(0, 1 - elapsedFade / OVERFLOW_FADE)
        item.frame:SetAlpha(ActionTrailDB.opacity * factor)
        placeItem(item)
        if factor <= 0 then
            table.remove(fadingOut, i)
            recycle(item)
        end
    end
end

root:SetScript("OnUpdate", function(_, elapsed)
    updateMotion(elapsed)
    root._fadeElapsed = (root._fadeElapsed or 0) + elapsed
    if root._fadeElapsed >= 0.05 then
        root._fadeElapsed = 0
        updateFade()
    end
end)

local events = CreateFrame("Frame")
local playerEvents = {
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP",
}

for _, ev in ipairs(playerEvents) do
    local ok
    if events.RegisterUnitEvent then
        ok = pcall(events.RegisterUnitEvent, events, ev, "player")
    else
        ok = pcall(events.RegisterEvent, events, ev)
    end
    if ev == "UNIT_SPELLCAST_SENT" then requestEventAvailable = ok == true end
end

events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
pcall(events.RegisterEvent, events, "START_AUTOREPEAT_SPELL")
pcall(events.RegisterEvent, events, "STOP_AUTOREPEAT_SPELL")
events:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        suppressUntil = GetTime() + QUIET_AFTER_LOGIN
        applyVisibility()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        applyVisibility()
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        shootDebugTargetGUID = nil
        shootTrailTargetGUID = nil
        return
    end

    if event == "START_AUTOREPEAT_SPELL" then
        handleAutoRepeatStart()
        return
    end

    if event == "STOP_AUTOREPEAT_SPELL" then
        handleAutoRepeatStop()
        return
    end

    if event == "UNIT_SPELLCAST_SENT" then
        local _, castGUID, spellID = ...
        noteRequest(castGUID, spellID)
        return
    end

    if unit ~= "player" or GetTime() < suppressUntil then return end
    local castGUID, spellID = ...
    handleSpellEvent(event, castGUID, spellID)
end)

local function applyErrorSuppression()
    if not UIErrorsFrame or not ActionTrailDB then return end
    if ActionTrailDB.hideActionErrors then
        UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    else
        UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON then return end
    mergeDefaults()
    ensureDebugFrame()
    applyLayout()
    applyLock()
    applyVisibility()
    applyErrorSuppression()
    C_Timer.After(0.5, scanGSEExecutors)
    C_Timer.NewTicker(2.0, function()
        if ActionTrailDB and ActionTrailDB.gseDebug then scanGSEExecutors() end
    end)
    loader:UnregisterAllEvents()
end)

local function setBool(key, value)
    ActionTrailDB[key] = value
end

local function printStatus()
    print(("ActionTrail " .. VERSION .. ": wand=%s, autoshot=%s, melee=%s, combatOnly=%s, fade=%s, history=%d"):format(
        ActionTrailDB.showWand and "on" or "off",
        ActionTrailDB.showAutoShot and "on" or "off",
        ActionTrailDB.showMelee and "on" or "off",
        ActionTrailDB.onlyInCombat and "on" or "off",
        ActionTrailDB.fadeEnabled and ("on/" .. tostring(ActionTrailDB.fadeSeconds) .. "s") or "off",
        ActionTrailDB.maxIcons))
    print(("ActionTrail UI errors: %s"):format(ActionTrailDB.hideActionErrors and "hidden" or "shown"))
    print(("ActionTrail GSE debug: %s, click#=%s, showEmpty=%s, markEmpty=%s, latency=%s, combatOnly=%s, rows=%d"):format(
        ActionTrailDB.gseDebug and "on" or "off",
        ActionTrailDB.gseClickNumbers and "on" or "off",
        ActionTrailDB.gseShowEmpty and "on" or "off",
        ActionTrailDB.gseMarkEmpty and "on" or "off",
        ActionTrailDB.gseLatency and "on" or "off",
        ActionTrailDB.gseDebugCombatOnly and "on" or "off",
        ActionTrailDB.gseDebugRows))
    print(("ActionTrail GSE hooks: %d"):format(gseHookCount))
end

local menu

local function makeCheck(parent, label, x, y, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    local text = cb.Text or cb.text
    if not text then
        text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    end
    text:SetText(label)
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() == true) end)
    cb.Refresh = function(self) self:SetChecked(getter() == true) end
    return cb
end

local function makeSlider(parent, label, x, y, minV, maxV, step, getter, setter, width)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", x, y)
    title:SetText(label)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y - 22)
    slider:SetWidth(width or 260)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(tostring(minV))
    slider.High:SetText(tostring(maxV))
    slider.Text:SetText("")

    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("LEFT", slider, "RIGHT", 12, 0)

    slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        value:SetText(tostring(v))
        setter(v)
    end)
    slider.Refresh = function(self)
        local v = getter()
        self:SetValue(v)
        value:SetText(tostring(v))
    end
    return slider
end

local function updateMinimapButtonPosition()
    if not minimapButton or not ActionTrailDB then return end
    local angle = math.rad(tonumber(ActionTrailDB.minimapAngle) or 220)
    -- Put the button outside the minimap instead of on top of the map texture.
    -- Half the minimap size + half the button + a small gap keeps the whole
    -- button outside, while still following the minimap's actual scale/size.
    local mapRadius = math.max(Minimap:GetWidth() or 140, Minimap:GetHeight() or 140) / 2
    local radius = mapRadius + 18
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

createMinimapButton = function()
    if minimapButton then return minimapButton end

    local b = CreateFrame("Button", "ActionTrailMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetMovable(true)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)

    local icon = b:CreateTexture(nil, "ARTWORK")
    -- Use the TGA explicitly. WoW can show a solid green placeholder when an
    -- unsupported/ambiguous texture source is selected.
    icon:SetTexture("Interface\\AddOns\\ActionTrail\\ActionTrailIcon.tga")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    local highlight = b:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ActionTrailDB.gseDebug = not ActionTrailDB.gseDebug
            if ActionTrailDB.gseDebug then scanGSEExecutors() else gsePending = {} end
            refreshDebugFrame()
            print("ActionTrail: GSE-Debug " .. (ActionTrailDB.gseDebug and T("debugOn") or T("debugOff")))
        else
            toggleMenu()
        end
    end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ActionTrail " .. VERSION)
        GameTooltip:AddLine(T("tipLeft"), 1, 1, 1)
        GameTooltip:AddLine(T("tipRight"), 1, 1, 1)
        GameTooltip:AddLine(T("tipDrag"), 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            ActionTrailDB.minimapAngle = angle
            updateMinimapButtonPosition()
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    minimapButton = b
    updateMinimapButtonPosition()
    if ActionTrailDB and ActionTrailDB.showMinimapButton == false then b:Hide() end
    return b
end

applyMinimapVisibility = function()
    if not minimapButton then return end
    minimapButton:SetShown(ActionTrailDB and ActionTrailDB.showMinimapButton ~= false)
end

local function buildMenu()
    if menu then return menu end
    menu = CreateFrame("Frame", "ActionTrailOptions", UIParent, "BackdropTemplate")
    menu:SetSize(460, 730)
    menu:SetPoint("CENTER")
    menu:SetFrameStrata("DIALOG")
    menu:SetMovable(true)
    menu:EnableMouse(true)
    menu:RegisterForDrag("LeftButton")
    menu:SetScript("OnDragStart", menu.StartMoving)
    menu:SetScript("OnDragStop", menu.StopMovingOrSizing)
    menu:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Tooltips/UI-Tooltip-Border", edgeSize=12})
    menu:SetBackdropColor(0.04,0.04,0.04,0.96)
    menu:SetBackdropBorderColor(0.6,0.6,0.6,1)

    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("ActionTrail " .. VERSION)

    local close = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local langLabel = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    langLabel:SetPoint("TOPRIGHT", -178, -20)
    langLabel:SetText(T("language") .. ":")

    local function makeLanguageButton(text, lang, anchor, xOffset)
        local b = CreateFrame("Button", nil, menu, "BackdropTemplate")
        b:SetSize(48, 22)
        b:SetPoint("LEFT", anchor, "RIGHT", xOffset or 4, 0)
        b:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8X8",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 10,
        })

        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER", 0, 0)
        fs:SetText(text)
        b.label = fs

        function b:Refresh()
            local active = ActionTrailDB.language == lang
            if active then
                self:SetBackdropColor(0.28, 0.20, 0.02, 0.95)
                self:SetBackdropBorderColor(1.00, 0.82, 0.15, 1)
                self.label:SetTextColor(1.00, 0.82, 0.15, 1)
            else
                self:SetBackdropColor(0.05, 0.05, 0.05, 0.90)
                self:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
                self.label:SetTextColor(0.82, 0.82, 0.82, 1)
            end
        end

        b:SetScript("OnEnter", function(self)
            if ActionTrailDB.language ~= lang then
                self:SetBackdropBorderColor(0.85, 0.70, 0.12, 1)
                self.label:SetTextColor(1.00, 0.90, 0.35, 1)
            end
        end)
        b:SetScript("OnLeave", function(self) self:Refresh() end)
        b:SetScript("OnClick", function()
            if ActionTrailDB.language ~= lang then
                ActionTrailDB.language = lang
                print("ActionTrail: " .. STRINGS[lang].langChanged)
                ReloadUI()
            end
        end)

        b:Refresh()
        return b
    end

    local deBtn = makeLanguageButton("DE", "de", langLabel, 6)
    local enBtn = makeLanguageButton("EN", "en", deBtn, 4)
    menu.langButtons = { deBtn, enBtn }

    menu.controls = {}
    local function add(c) table.insert(menu.controls, c); return c end

    add(makeCheck(menu, T("wand"), 20, -58,
        function() return ActionTrailDB.showWand end,
        function(v) ActionTrailDB.showWand=v end))
    add(makeCheck(menu, T("autoshot"), 20, -88,
        function() return ActionTrailDB.showAutoShot end,
        function(v) ActionTrailDB.showAutoShot=v end))
    add(makeCheck(menu, T("melee"), 20, -118,
        function() return ActionTrailDB.showMelee end,
        function(v) ActionTrailDB.showMelee=v end))
    add(makeCheck(menu, T("minimap"), 20, -148,
        function() return ActionTrailDB.showMinimapButton end,
        function(v) ActionTrailDB.showMinimapButton=v; applyMinimapVisibility() end))

    add(makeSlider(menu, T("historyIcons"), 20, -188, 1, 10, 1,
        function() return ActionTrailDB.maxIcons end,
        function(v) ActionTrailDB.maxIcons=v; trim(); applyLayout() end))

    add(makeSlider(menu, T("iconSize"), 20, -256, 16, 64, 1,
        function() return ActionTrailDB.iconSize end,
        function(v) ActionTrailDB.iconSize=v; applyLayout() end))

    add(makeCheck(menu, T("combatOnly"), 20, -328,
        function() return ActionTrailDB.onlyInCombat end,
        function(v) ActionTrailDB.onlyInCombat=v; applyVisibility() end))

    local fadeCheck = add(makeCheck(menu, T("fade"), 20, -358,
        function() return ActionTrailDB.fadeEnabled end,
        function(v) ActionTrailDB.fadeEnabled=v; if not v then updateFade() end end))

    add(makeSlider(menu, T("fadeSeconds"), 20, -398, 2, 20, 1,
        function() return ActionTrailDB.fadeSeconds end,
        function(v) ActionTrailDB.fadeSeconds=v end))

    add(makeCheck(menu, T("hideErrors"), 250, -328,
        function() return ActionTrailDB.hideActionErrors end,
        function(v)
            ActionTrailDB.hideActionErrors = v
            applyErrorSuppression()
            print("ActionTrail: " .. (v and T("errorsHidden") or T("errorsShown")))
        end))

    local dbgTitle = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dbgTitle:SetPoint("TOPLEFT", 20, -448)
    dbgTitle:SetText(T("gseTitle"))

    add(makeCheck(menu, T("gseTriggers"), 20, -472,
        function() return ActionTrailDB.gseDebug end,
        function(v)
            ActionTrailDB.gseDebug=v
            if v then scanGSEExecutors() else gsePending = {} end
            refreshDebugFrame()
        end))
    add(makeCheck(menu, T("clickNumber"), 20, -502,
        function() return ActionTrailDB.gseClickNumbers end,
        function(v) ActionTrailDB.gseClickNumbers=v; refreshDebugFrame() end))
    add(makeCheck(menu, T("markEmpty"), 20, -532,
        function() return ActionTrailDB.gseMarkEmpty end,
        function(v) ActionTrailDB.gseMarkEmpty=v; refreshDebugFrame() end))
    add(makeCheck(menu, T("latency"), 20, -562,
        function() return ActionTrailDB.gseLatency end,
        function(v) ActionTrailDB.gseLatency=v; refreshDebugFrame() end))
    add(makeCheck(menu, T("gseCombatOnly"), 20, -592,
        function() return ActionTrailDB.gseDebugCombatOnly end,
        function(v) ActionTrailDB.gseDebugCombatOnly=v; refreshDebugFrame() end))

    add(makeCheck(menu, T("showGSEFrameInfo"), 250, -442,
        function() return ActionTrailDB.showGSEFrameInfo end,
        function(v) ActionTrailDB.showGSEFrameInfo=v; refreshDebugFrame() end))

    add(makeSlider(menu, T("debugHistory"), 250, -492, 3, 15, 1,
        function() return ActionTrailDB.gseDebugRows end,
        function(v) ActionTrailDB.gseDebugRows=v; trimGSEHistory(); refreshDebugFrame() end, 145))

    add(makeCheck(menu, T("showEmpty"), 250, -548,
        function() return ActionTrailDB.gseShowEmpty end,
        function(v) ActionTrailDB.gseShowEmpty=v; trimGSEHistory(); refreshDebugFrame() end))

    local clearBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    clearBtn:SetSize(170, 24)
    clearBtn:SetPoint("TOPLEFT", 250, -585)
    clearBtn:SetText(T("clearDebug"))
    clearBtn:SetScript("OnClick", function()
        gseHistory = {}
        gsePending = {}
        gseClickSerial = 0
        refreshDebugFrame()
    end)

    local moveBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    moveBtn:SetSize(150, 24)
    moveBtn:SetPoint("BOTTOMLEFT", 20, 18)
    moveBtn:SetScript("OnClick", function()
        ActionTrailDB.locked = not ActionTrailDB.locked
        applyLock()
        applyVisibility()
        moveBtn:SetText(ActionTrailDB.locked and T("unlock") or T("lock"))
    end)
    menu.moveBtn = moveBtn

    local resetBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    resetBtn:SetSize(150, 24)
    resetBtn:SetPoint("BOTTOMRIGHT", -20, 18)
    resetBtn:SetText(T("reset"))
    resetBtn:SetScript("OnClick", function()
        for k,v in pairs(defaults) do ActionTrailDB[k]=v end
        gseHistory = {}; gsePending = {}; gseClickSerial = 0
        trim(); applyLayout(); applyLock(); applyVisibility(); updateFade(); refreshDebugFrame(); applyMinimapVisibility(); applyErrorSuppression()
        if menu.Refresh then menu:Refresh() end
    end)

    function menu:Refresh()
        for _, c in ipairs(self.controls) do if c.Refresh then c:Refresh() end end
        if self.langButtons then
            for _, b in ipairs(self.langButtons) do if b.Refresh then b:Refresh() end end
        end
        self.moveBtn:SetText(ActionTrailDB.locked and T("unlock") or T("lock"))
    end

    menu:SetScript("OnShow", function(self) self:Refresh() end)
    menu:Hide()
    return menu
end

toggleMenu = function()
    local m = buildMenu()
    if m:IsShown() then m:Hide() else m:Show() end
end

SLASH_ACTIONTRAIL1 = "/at"
SlashCmdList.ACTIONTRAIL = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "" or msg == "menu" or msg == "config" then
        toggleMenu(); return
    end

    if msg == "unlock" then
        ActionTrailDB.locked = false; applyLock(); print("ActionTrail: " .. T("unlocked"))
        return
    elseif msg == "lock" then
        ActionTrailDB.locked = true; applyLock(); print("ActionTrail: " .. T("locked"))
        return
    elseif msg == "reset" then
        ActionTrailDB.x, ActionTrailDB.y = defaults.x, defaults.y
        ActionTrailDB.iconSize, ActionTrailDB.maxIcons = defaults.iconSize, defaults.maxIcons
        applyLayout(); print("ActionTrail: " .. T("resetDone"))
        return
    elseif msg == "status" then
        printStatus(); return
    end

    local lang = msg:match("^lang%s+(de|en)$")
    if lang then
        if ActionTrailDB.language ~= lang then
            ActionTrailDB.language = lang
            print("ActionTrail: " .. (STRINGS[lang] and STRINGS[lang].langChanged or "Language changed."))
            ReloadUI()
        end
        return
    end

    local mm = msg:match("^minimap%s+(on|off)$")
    if mm then
        ActionTrailDB.showMinimapButton = (mm == "on")
        applyMinimapVisibility()
        return
    end

    local n = msg:match("^size%s+(%d+)$")
    if n then
        ActionTrailDB.iconSize = math.max(16, math.min(64, tonumber(n)))
        applyLayout(); return
    end

    n = msg:match("^count%s+(%d+)$")
    if n then
        ActionTrailDB.maxIcons = math.max(1, math.min(10, tonumber(n)))
        trim(); applyLayout(); return
    end

    local key, state = msg:match("^(wand)%s+(on|off)$")
    if key then setBool("showWand", state == "on"); printStatus(); return end
    key, state = msg:match("^(autoshot)%s+(on|off)$")
    if key then setBool("showAutoShot", state == "on"); printStatus(); return end
    key, state = msg:match("^(melee)%s+(on|off)$")
    if key then setBool("showMelee", state == "on"); printStatus(); return end
    key, state = msg:match("^(auto)%s+(on|off)$")
    if key then
        local on = state == "on"
        setBool("showWand", on); setBool("showAutoShot", on); setBool("showMelee", on)
        printStatus(); return
    end

    key, state = msg:match("^(combat)%s+(on|off)$")
    if key then setBool("onlyInCombat", state == "on"); applyVisibility(); printStatus(); return end
    key, state = msg:match("^(errors)%s+(on|off)$")
    if key then
        setBool("hideActionErrors", state == "off")
        applyErrorSuppression()
        print("ActionTrail: " .. (ActionTrailDB.hideActionErrors and T("errorsHidden") or T("errorsShown")))
        return
    end

    key, state = msg:match("^(fade)%s+(on|off)$")
    if key then setBool("fadeEnabled", state == "on"); if state == "off" then updateFade() end; printStatus(); return end

    n = msg:match("^fadetime%s+(%d+)$")
    if n then ActionTrailDB.fadeSeconds = math.max(2, math.min(20, tonumber(n))); printStatus(); return end

    key, state = msg:match("^(gsedebug)%s+(on|off)$")
    if key then
        setBool("gseDebug", state == "on")
        if state == "on" then scanGSEExecutors() else gsePending = {} end
        refreshDebugFrame(); printStatus(); return
    end

    key, state = msg:match("^(gseempty)%s+(on|off)$")
    if key then
        setBool("gseShowEmpty", state == "on")
        trimGSEHistory(); refreshDebugFrame(); printStatus(); return
    end

    if msg == "gsescan" then
        scanGSEExecutors()
        print(("ActionTrail: GSE scan complete, hooked executors=%d"):format(gseHookCount))
        return
    end

    if msg == "gseclear" then
        gseHistory = {}; gsePending = {}; gseClickSerial = 0; refreshDebugFrame(); return
    end

    print("ActionTrail: /at (" .. T("menuWord") .. ") | lang de/en | unlock | lock | reset | size 16-64 | count 1-10 | auto on/off | wand on/off | autoshot on/off | melee on/off | combat on/off | errors on/off | fade on/off | fadetime 2-20 | gsedebug on/off | gseempty on/off | gsescan | gseclear | status")
end
