-- ============================================================
-- CODE SNIPER  v9  (mini / rebranded)
-- One compact panel. Custom-code entry + [F] monitor sniper.
-- Listens to NotificationService/Notify (RE) and
-- AdminService/Announce (RF/RE). Press F to arm: the next code
-- in an announcement is auto-typed and insta-redeemed.
-- ============================================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PG  = Player:WaitForChild("PlayerGui")
local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")

-- ── marker-based remote finder ───────────────────────────────────
local function findRemoteByMarker(markerName, expectedClass)
    local children = Net:GetChildren()
    for i = 1, #children - 1 do
        if children[i].Name == markerName then
            local r = children[i + 1]
            if r and r:IsA(expectedClass) then return r end
        end
    end
end

local NotifyRemote   = findRemoteByMarker("RE/NotificationService/Notify", "RemoteEvent")
local AnnounceRemote = findRemoteByMarker("RF/AdminService/Announce", "RemoteFunction")
    or findRemoteByMarker("RF/AdminService/Announce", "RemoteEvent")
local RedeemRemote   = findRemoteByMarker("RF/RequestRedemption", "RemoteFunction")

print("[Sniper] Notify:",  NotifyRemote   and NotifyRemote.Name   or "MISSING")
print("[Sniper] Announce:", AnnounceRemote and AnnounceRemote.Name or "MISSING")
print("[Sniper] Redeem:",  RedeemRemote   and RedeemRemote.Name   or "MISSING")

-- ── Config ───────────────────────────────────────────────────────
local MIN_WORD_LEN, MAX_WORD_LEN = 4, 30

local BORING = {}
for _, w in ipairs({
    "HEY","HI","HELLO","YO","GUYS","MAKE","SURE","HAVE","FAST","FINGERS",
    "CODE","CODES","READY","OK","OKAY","YES","NO","WAIT","NOW","GO","START",
    "EVENT","EVENTS","THIS","THAT","THE","ARE","YOU","WE","US","ME","IT",
    "IS","ISNT","WAS","WILL","SHALL","CAN","CANT","DO","DONT","DID",
    "AND","OR","BUT","FOR","TO","FROM","IN","ON","AT","BY","OF","WITH",
    "EVERYONE","EVERY","SOON","JUST","FREE","BRAINROT","REDEEM","REDEEMED",
    "ERROR","SUCCESS","FAIL","FAILED","INVALID","EXPIRED","ALREADY",
    "TRUE","FALSE","NULL","NONE","SERVER","CLIENT","PLAYER","GAME","ADMIN",
    "HTTP","HTTPS","WWW","COM","NET","ORG","DISCORD","ANNOUNCE","ANNOUNCEMENT",
}) do BORING[w] = true end

-- ── Helpers ──────────────────────────────────────────────────────
local function stripRich(s) if type(s) ~= "string" then return tostring(s) end; return (s:gsub("<[^>]+>", "")) end
local function isCandidate(token)
    if #token < MIN_WORD_LEN or #token > MAX_WORD_LEN then return false end
    if BORING[token:upper()] then return false end
    local hasDigit = token:match("%d") ~= nil
    local allUp = token:upper() == token and token:match("%a") ~= nil
    return allUp or hasDigit
end
local function tokenize(text) local t = {}; for raw in text:gmatch("[%w_]+") do table.insert(t, raw) end; return t end
local function copyText(s)
    for _, fn in ipairs({setclipboard, toclipboard, (syn and syn.write_clipboard)}) do
        if fn then local ok = pcall(fn, s); if ok then return true end end
    end
    return false
end
local function redeem(code)
    if not RedeemRemote then return false, "no remote" end
    local ok, result = pcall(function() return RedeemRemote:InvokeServer(code) end)
    if not ok then return false, tostring(result) end
    return true, result
end

-- ── Palette (rebrand: dim, slightly-transparent white — no pink) ──
local K = {
    bg   = Color3.fromRGB(12,12,14),  bg1  = Color3.fromRGB(17,17,20),
    bg2  = Color3.fromRGB(23,23,27),  bg3  = Color3.fromRGB(31,31,36),
    bg4  = Color3.fromRGB(42,42,48),
    line = Color3.fromRGB(46,46,52),  bdr  = Color3.fromRGB(72,72,82),
    txt  = Color3.fromRGB(232,233,238), txt2 = Color3.fromRGB(165,167,176),
    txt3 = Color3.fromRGB(94,96,105),
    acc      = Color3.fromRGB(196,199,208), -- dim white accent
    accDim   = Color3.fromRGB(150,153,162),
    accHov   = Color3.fromRGB(222,224,230),
    accPress = Color3.fromRGB(120,123,132),
    ok    = Color3.fromRGB(70,190,110), err = Color3.fromRGB(210,80,80),
    amber = Color3.fromRGB(230,180,70),
    input = Color3.fromRGB(20,20,24),
}

local function mk(c,p) local o=Instance.new(c); if p then o.Parent=p end; return o end
local function corner(r,p) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r) end
local function stroke(p,c,t,tr) local s=Instance.new("UIStroke",p); s.Color=c or K.bdr; s.Thickness=t or 1; s.Transparency=tr or 0; return s end
local function tw(o,t,g,es,ed) return TweenService:Create(o,TweenInfo.new(t,es or Enum.EasingStyle.Quad,ed or Enum.EasingDirection.Out),g):Play() end
local function twB(o,t,g) TweenService:Create(o,TweenInfo.new(t,Enum.EasingStyle.Back,Enum.EasingDirection.Out),g):Play() end
local function label(t,sz,fn,c,xa,par)
    local l=mk("TextLabel",par); l.BackgroundTransparency=1; l.Text=t or ""
    l.TextSize=sz or 11; l.Font=fn or Enum.Font.Gotham
    l.TextColor3=c or K.txt; l.TextXAlignment=xa or Enum.TextXAlignment.Left; return l
end

-- wipe any previous build
for _, n in ipairs({"AnnouncementSniperGUI","AnnouncementSniperWM","AnnouncementSniperCustom","CodeSniperLite"}) do
    local old = PG:FindFirstChild(n); if old then old:Destroy() end
end

-- ══ PANEL ════════════════════════════════════════════════════════
local SG = mk("ScreenGui"); SG.Name = "CodeSniperLite"
SG.ResetOnSpawn = false; SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 201; SG.Parent = PG

local PW, PH   = 300, 252
local HEAD_H   = 42

local Main = mk("Frame", SG); Main.Name = "Main"
Main.Size = UDim2.new(0, PW, 0, PH)
Main.Position = UDim2.new(1, -PW - 24, 0.5, -PH/2)
Main.BackgroundColor3 = K.bg
Main.BackgroundTransparency = 0.12   -- slightly transparent
Main.BorderSizePixel = 0; Main.ClipsDescendants = true; Main.ZIndex = 10
corner(14, Main)
stroke(Main, K.bdr, 1.4, 0.25)

-- header
local Head = mk("Frame", Main)
Head.Size = UDim2.new(1, 0, 0, HEAD_H); Head.BackgroundColor3 = K.bg1
Head.BackgroundTransparency = 0.08; Head.BorderSizePixel = 0; Head.ZIndex = 11
corner(14, Head)
local headMask = mk("Frame", Head); headMask.Size = UDim2.new(1,0,0,12)
headMask.Position = UDim2.new(0,0,1,-12); headMask.BackgroundColor3 = K.bg1
headMask.BackgroundTransparency = 0.08; headMask.BorderSizePixel = 0; headMask.ZIndex = 11

-- marker dot (replaces the old logo image) — dim white, slightly transparent
local mark = mk("Frame", Head)
mark.Size = UDim2.new(0, 10, 0, 10); mark.AnchorPoint = Vector2.new(0, 0.5)
mark.Position = UDim2.new(0, 14, 0.5, 0); mark.BackgroundColor3 = K.acc
mark.BackgroundTransparency = 0.25; mark.BorderSizePixel = 0; mark.ZIndex = 12
corner(5, mark)
task.spawn(function()
    while mark and mark.Parent do
        tw(mark, 1.1, {BackgroundTransparency = 0.55}, Enum.EasingStyle.Sine); task.wait(1.2)
        if not (mark and mark.Parent) then break end
        tw(mark, 1.1, {BackgroundTransparency = 0.2}, Enum.EasingStyle.Sine); task.wait(1.2)
    end
end)

local title = label("CUSTOM CODE", 12, Enum.Font.GothamBlack, K.txt, nil, Head)
title.Size = UDim2.new(1, -90, 0, 14); title.Position = UDim2.new(0, 32, 0, 6); title.ZIndex = 12
local sub = label("monitor · type · redeem · [F]", 8, Enum.Font.Gotham, K.txt2, nil, Head)
sub.Size = UDim2.new(1, -90, 0, 11); sub.Position = UDim2.new(0, 32, 0, 23); sub.ZIndex = 12

local close = mk("TextButton", Head)
close.Size = UDim2.new(0, 22, 0, 22); close.AnchorPoint = Vector2.new(1, 0.5)
close.Position = UDim2.new(1, -10, 0.5, 0); close.BackgroundColor3 = K.bg3
close.TextColor3 = K.txt2; close.Font = Enum.Font.GothamBold; close.TextSize = 11
close.Text = "X"; close.BorderSizePixel = 0; close.AutoButtonColor = false; close.ZIndex = 13
corner(11, close); stroke(close, K.bdr, 1, 0)
close.MouseEnter:Connect(function() tw(close, 0.1, {BackgroundColor3 = K.err, TextColor3 = K.txt}) end)
close.MouseLeave:Connect(function() tw(close, 0.1, {BackgroundColor3 = K.bg3, TextColor3 = K.txt2}) end)
close.MouseButton1Click:Connect(function() Main.Visible = false end)

-- drag
local function attachDrag(handle, target)
    local d, ds, sp = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            d = true; ds = i.Position; sp = target.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then d = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not d then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local dd = i.Position - ds
            target.Position = UDim2.new(sp.X.Scale, sp.X.Offset+dd.X, sp.Y.Scale, sp.Y.Offset+dd.Y)
        end
    end)
end
attachDrag(Head, Main)

-- content
local content = mk("Frame", Main)
content.Size = UDim2.new(1, -20, 1, -(HEAD_H + 12))
content.Position = UDim2.new(0, 10, 0, HEAD_H + 6)
content.BackgroundTransparency = 1; content.ZIndex = 11

-- code box
local boxCard = mk("Frame", content)
boxCard.Size = UDim2.new(1, 0, 0, 50); boxCard.Position = UDim2.new(0, 0, 0, 0)
boxCard.BackgroundColor3 = K.bg2; boxCard.BackgroundTransparency = 0.08
boxCard.BorderSizePixel = 0; boxCard.ZIndex = 12
corner(8, boxCard); stroke(boxCard, K.line, 1, 0.3)

local boxLbl = label("CODE", 9, Enum.Font.GothamBlack, K.accDim, nil, boxCard)
boxLbl.Size = UDim2.new(1, -18, 0, 10); boxLbl.Position = UDim2.new(0, 10, 0, 5); boxLbl.ZIndex = 13

local CodeBox = mk("TextBox", boxCard)
CodeBox.Size = UDim2.new(1, -18, 0, 28); CodeBox.Position = UDim2.new(0, 9, 1, -32)
CodeBox.BackgroundColor3 = K.input; CodeBox.BorderSizePixel = 0
CodeBox.PlaceholderText = "type code here..."
CodeBox.PlaceholderColor3 = Color3.fromRGB(110, 112, 122)
CodeBox.Text = ""; CodeBox.TextColor3 = K.txt
CodeBox.Font = Enum.Font.GothamBlack; CodeBox.TextSize = 15
CodeBox.ClearTextOnFocus = false; CodeBox.ZIndex = 13
CodeBox.TextXAlignment = Enum.TextXAlignment.Left
corner(6, CodeBox)
local cbPad = mk("UIPadding", CodeBox)
cbPad.PaddingLeft = UDim.new(0, 8); cbPad.PaddingRight = UDim.new(0, 8)
local boxStroke = stroke(CodeBox, K.bdr, 1.2, 0.25)
CodeBox.Focused:Connect(function() tw(boxStroke, 0.12, {Color = K.acc, Transparency = 0.05, Thickness = 1.4}) end)
CodeBox.FocusLost:Connect(function() tw(boxStroke, 0.12, {Color = K.bdr, Transparency = 0.25, Thickness = 1.2}) end)

-- COPY / REDEEM row
local btnRow = mk("Frame", content)
btnRow.Size = UDim2.new(1, 0, 0, 32); btnRow.Position = UDim2.new(0, 0, 0, 58)
btnRow.BackgroundTransparency = 1; btnRow.ZIndex = 12

local cCopy = mk("TextButton", btnRow)
cCopy.Size = UDim2.new(0.40, -4, 1, 0); cCopy.Position = UDim2.new(0, 0, 0, 0)
cCopy.BackgroundColor3 = K.bg2; cCopy.BorderSizePixel = 0
cCopy.Text = "COPY"; cCopy.TextColor3 = K.txt
cCopy.Font = Enum.Font.GothamBlack; cCopy.TextSize = 12
cCopy.AutoButtonColor = false; cCopy.ZIndex = 13
corner(6, cCopy); stroke(cCopy, K.bdr, 1.2, 0.1)
cCopy.MouseEnter:Connect(function() tw(cCopy, 0.1, {BackgroundColor3 = K.bg4, TextColor3 = K.accHov}) end)
cCopy.MouseLeave:Connect(function() tw(cCopy, 0.1, {BackgroundColor3 = K.bg2, TextColor3 = K.txt}) end)

local cRedeem = mk("TextButton", btnRow)
cRedeem.Size = UDim2.new(0.60, -4, 1, 0); cRedeem.Position = UDim2.new(0.40, 4, 0, 0)
cRedeem.BackgroundColor3 = K.acc; cRedeem.BorderSizePixel = 0
cRedeem.Text = "REDEEM"; cRedeem.TextColor3 = Color3.fromRGB(18, 18, 22)
cRedeem.Font = Enum.Font.GothamBlack; cRedeem.TextSize = 13
cRedeem.AutoButtonColor = false; cRedeem.ZIndex = 13
corner(6, cRedeem); stroke(cRedeem, K.accHov, 1.2, 0.4)
cRedeem.MouseEnter:Connect(function() tw(cRedeem, 0.08, {BackgroundColor3 = K.accHov}) end)
cRedeem.MouseLeave:Connect(function() tw(cRedeem, 0.08, {BackgroundColor3 = K.acc}) end)

-- MONITOR [F] toggle row
local monRow = mk("Frame", content)
monRow.Size = UDim2.new(1, 0, 0, 28); monRow.Position = UDim2.new(0, 0, 0, 96)
monRow.BackgroundColor3 = K.bg2; monRow.BackgroundTransparency = 0.08
monRow.BorderSizePixel = 0; monRow.ZIndex = 12
corner(7, monRow); stroke(monRow, K.line, 1, 0.3)

local monLbl = label("MONITOR", 10, Enum.Font.GothamBold, K.txt2, nil, monRow)
monLbl.Size = UDim2.new(1, -110, 1, 0); monLbl.Position = UDim2.new(0, 10, 0, 0); monLbl.ZIndex = 13

local keyHint = mk("Frame", monRow)
keyHint.Size = UDim2.new(0, 18, 0, 16); keyHint.AnchorPoint = Vector2.new(1, 0.5)
keyHint.Position = UDim2.new(1, -52, 0.5, 0); keyHint.BackgroundColor3 = K.bg4
keyHint.BorderSizePixel = 0; keyHint.ZIndex = 13; corner(4, keyHint); stroke(keyHint, K.bdr, 1, 0.2)
label("F", 9, Enum.Font.GothamBlack, K.txt, Enum.TextXAlignment.Center, keyHint).Size = UDim2.new(1,0,1,0)

local pill = mk("Frame", monRow); pill.Size = UDim2.new(0, 34, 0, 16)
pill.AnchorPoint = Vector2.new(1, 0.5); pill.Position = UDim2.new(1, -10, 0.5, 0)
pill.BackgroundColor3 = K.txt3; pill.BorderSizePixel = 0; pill.ZIndex = 13; corner(8, pill)
local dot = mk("Frame", pill); dot.Size = UDim2.new(0, 12, 0, 12)
dot.Position = UDim2.new(0, 2, 0.5, -6); dot.BackgroundColor3 = K.txt
dot.BorderSizePixel = 0; dot.ZIndex = 14; corner(6, dot)
local monBtn = mk("TextButton", monRow); monBtn.Size = UDim2.new(1, 0, 1, 0)
monBtn.BackgroundTransparency = 1; monBtn.Text = ""; monBtn.ZIndex = 15

-- status
local cStatus = mk("Frame", content)
cStatus.Size = UDim2.new(1, 0, 0, 50); cStatus.Position = UDim2.new(0, 0, 0, 130)
cStatus.BackgroundColor3 = K.bg2; cStatus.BackgroundTransparency = 0.08
cStatus.BorderSizePixel = 0; cStatus.ZIndex = 12
corner(7, cStatus); stroke(cStatus, K.line, 1, 0.3)

local cStatusHdr = label("STATUS", 8, Enum.Font.GothamBlack, K.accDim, nil, cStatus)
cStatusHdr.Size = UDim2.new(1, -18, 0, 10); cStatusHdr.Position = UDim2.new(0, 10, 0, 5); cStatusHdr.ZIndex = 13

local cStatusDot = mk("Frame", cStatus)
cStatusDot.Size = UDim2.new(0, 7, 0, 7); cStatusDot.AnchorPoint = Vector2.new(0, 0.5)
cStatusDot.Position = UDim2.new(0, 10, 0, 30); cStatusDot.BackgroundColor3 = K.txt3
cStatusDot.BorderSizePixel = 0; cStatusDot.ZIndex = 13; corner(50, cStatusDot)

local cStatusLbl = label("type a code, or press F to snipe.", 11, Enum.Font.GothamBold, K.txt, nil, cStatus)
cStatusLbl.Size = UDim2.new(1, -30, 0, 26); cStatusLbl.Position = UDim2.new(0, 22, 0, 17)
cStatusLbl.TextWrapped = true; cStatusLbl.TextYAlignment = Enum.TextYAlignment.Center; cStatusLbl.ZIndex = 13

local function setCStatus(text, kind)
    cStatusLbl.Text = text
    if kind == "ok" then cStatusLbl.TextColor3 = K.ok; cStatusDot.BackgroundColor3 = K.ok
    elseif kind == "err" then cStatusLbl.TextColor3 = K.err; cStatusDot.BackgroundColor3 = K.err
    elseif kind == "busy" then cStatusLbl.TextColor3 = K.accHov; cStatusDot.BackgroundColor3 = K.acc
    elseif kind == "armed" then cStatusLbl.TextColor3 = K.amber; cStatusDot.BackgroundColor3 = K.amber
    else cStatusLbl.TextColor3 = K.txt; cStatusDot.BackgroundColor3 = K.txt3 end
end

-- ── Redeem logic ─────────────────────────────────────────────────
local cBusy = false
local function runRedeem(code)
    if not code or code == "" then setCStatus("no code yet.", "err"); return end
    CodeBox.Text = code                 -- auto-type
    setCStatus("firing: " .. code, "busy")
    tw(cRedeem, 0.06, {BackgroundColor3 = K.accPress})
    local ok, result = redeem(code)
    tw(cRedeem, 0.1, {BackgroundColor3 = K.acc})
    if not ok then setCStatus("INVALID OR COOLDOWN: " .. code, "err"); return end
    if type(result) == "table" then
        local s = result.success or result.Success
        if s == true then setCStatus("REDEEMED: " .. code, "ok")
        else setCStatus("INVALID OR COOLDOWN: " .. code, "err") end
    else setCStatus("sent: " .. code, "ok") end
end

local function getCustomCode()
    return (CodeBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

cCopy.MouseButton1Click:Connect(function()
    local code = getCustomCode()
    if code == "" then setCStatus("enter a code first.", "err"); return end
    local ok = copyText(code)
    setCStatus(ok and ("copied: " .. code) or "copy failed", ok and "ok" or "err")
end)

local function fireCustom()
    if cBusy then return end
    local code = getCustomCode()
    if code == "" then setCStatus("enter a code first.", "err"); return end
    cBusy = true
    task.spawn(function() runRedeem(code); cBusy = false end)
end
cRedeem.MouseButton1Click:Connect(fireCustom)
CodeBox.FocusLost:Connect(function(enter) if enter then fireCustom() end end)

-- ── Monitor / [F] sniper ─────────────────────────────────────────
local monitorOn = false
local lastCapturedCode = nil
local seenAttempts = {}

local function setMonitor(v)
    monitorOn = v
    tw(pill, 0.15, {BackgroundColor3 = v and K.acc or K.txt3})
    tw(dot, 0.15, {Position = UDim2.new(0, v and 20 or 2, 0.5, -6)}, Enum.EasingStyle.Back)
    tw(monLbl, 0.15, {TextColor3 = v and K.accHov or K.txt2})
    tw(Main, 0.15, {BackgroundTransparency = v and 0.06 or 0.12})
    if v then setCStatus("armed — waiting for a code...", "armed")
    else setCStatus("monitor off.", "idle") end
end
monBtn.MouseButton1Click:Connect(function() setMonitor(not monitorOn) end)

local function snipe(code)
    if not code or code == "" then return end
    if seenAttempts[code] then return end
    seenAttempts[code] = true
    task.spawn(function() runRedeem(code) end)
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end                       -- ignore while typing in the box
    if input.KeyCode == Enum.KeyCode.F then
        setMonitor(not monitorOn)
        if monitorOn and lastCapturedCode then   -- already have one? fire it now
            snipe(lastCapturedCode)
        end
    end
end)

-- ── Announcement handler ─────────────────────────────────────────
local function handleAnnouncement(source, text, ...)
    local stripped = stripRich(tostring(text or "")); if stripped == "" then return end
    local found
    for _, tok in ipairs(tokenize(stripped)) do
        if isCandidate(tok) then found = tok; break end
    end
    if not found then return end
    lastCapturedCode = found
    if monitorOn then
        snipe(found)                              -- auto-type + insta-redeem
    else
        setCStatus("captured " .. found .. " — press F", "armed")
    end
end

if NotifyRemote then
    NotifyRemote.OnClientEvent:Connect(function(text, ...) handleAnnouncement("NOTIFY", text, ...) end)
    print("[Sniper] Notify hooked")
end
if AnnounceRemote then
    if AnnounceRemote:IsA("RemoteEvent") then
        AnnounceRemote.OnClientEvent:Connect(function(text, ...) handleAnnouncement("ADMIN", text, ...) end)
        print("[Sniper] Announce hooked via OnClientEvent")
    elseif AnnounceRemote:IsA("RemoteFunction") then
        local okSet = pcall(function()
            AnnounceRemote.OnClientInvoke = function(text, ...)
                pcall(handleAnnouncement, "ADMIN", text, ...)
                return nil
            end
        end)
        print(okSet and "[Sniper] Announce hooked via OnClientInvoke" or "[Sniper] Could not hook Announce")
    end
end

print("[Sniper] v9 ready.")
