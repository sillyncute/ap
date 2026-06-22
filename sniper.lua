-- ============================================================
-- PHI AUTOTYPER  v15  (mini)
-- Listens to ONLY the NotificationController 'Notify' remote (found via
-- its script, so the rotating hash never matters). Press the key (F) to
-- LISTEN: it collects the next N words the owner says, live-previews them
-- in the CODE box, and redeems instantly (0 delay). INSTA REDEEM toggle
-- lets you do it manually. The + button opens a TEST SENDER.
-- Remote names are hashed & rotate, so the announcement remote is
-- found by payload SHAPE (not name); the redeem remote is found by
-- name or learned on first manual use. See "REMOTE DISCOVERY".
-- ============================================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PG  = Player:WaitForChild("PlayerGui")
local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")

-- ── Remotes ──────────────────────────────────────────────────────
-- The game hashes & rotates remote names (e.g. RE/<64 hex chars>),
-- so we never hardcode a name. They are resolved by payload SHAPE in
-- the "REMOTE DISCOVERY" section near the bottom of this script.
local NotifyRemote, RedeemRemote = nil, nil

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
-- redeem instantly, zero delay (no rate-limit)
local function redeem(code)
    if not RedeemRemote then return false, "no remote" end
    local ok, result = pcall(function() return RedeemRemote:InvokeServer(code) end)
    if not ok then return false, tostring(result) end
    return true, result
end

-- ── Clean font set (Montserrat, with safe Gotham fallback) ───────
local function pickFont(getter, fallback)
    local ok, f = pcall(getter)
    if ok and typeof(f) == "EnumItem" then return f end
    return fallback
end
local F = {
    reg   = pickFont(function() return Enum.Font.Montserrat end,        Enum.Font.Gotham),
    med   = pickFont(function() return Enum.Font.MontserratMedium end,  Enum.Font.GothamMedium),
    bold  = pickFont(function() return Enum.Font.MontserratBold end,    Enum.Font.GothamBold),
    black = pickFont(function() return Enum.Font.MontserratBlack end,   Enum.Font.GothamBlack),
}

-- ── Palette (dim, slightly-transparent white — no pink) ──────────
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
local function label(t,sz,fn,c,xa,par)
    local l=mk("TextLabel",par); l.BackgroundTransparency=1; l.Text=t or ""
    l.TextSize=sz or 11; l.Font=fn or F.med
    l.TextColor3=c or K.txt; l.TextXAlignment=xa or Enum.TextXAlignment.Left; return l
end

-- shared drag
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

-- ── State (settings values; UI wires into these) ─────────────────
local monitorOn        = false
local lastCapturedCode = nil
local seenAttempts     = {}
local autoType         = true
local autoRedeem       = true     -- INSTA REDEEM toggle (main panel)
local caseMode         = "UPPER"  -- "UPPER" | "lower" | "BOTH"
local wordCount        = 1        -- words to collect per code (1/2/3)
local rawMode          = false    -- ignore WORDS+CASE; exact word(s) as typed
local collectBuffer    = {}       -- words gathered since listening started
local bindKey          = Enum.KeyCode.F
local rebinding        = false
local handleAnnouncement          -- forward declaration (assigned later)

-- wipe any previous build
for _, n in ipairs({"AnnouncementSniperGUI","AnnouncementSniperWM","AnnouncementSniperCustom","CodeSniperLite","PhiAutotyper"}) do
    local old = PG:FindFirstChild(n); if old then old:Destroy() end
end

-- ══ PANEL ════════════════════════════════════════════════════════
local SG = mk("ScreenGui"); SG.Name = "PhiAutotyper"
SG.ResetOnSpawn = false; SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 201; SG.Parent = PG

local PW, PH = 300, 274
local HEAD_H = 42

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

-- status dot (no logo image): grey = searching, green = remote locked
local mark = mk("Frame", Head)
mark.Size = UDim2.new(0, 10, 0, 10); mark.AnchorPoint = Vector2.new(0, 0.5)
mark.Position = UDim2.new(0, 14, 0.5, 0); mark.BackgroundColor3 = K.txt3
mark.BorderSizePixel = 0; mark.ZIndex = 12
corner(5, mark)

local title = label("PHI AUTOTYPER", 12, F.black, K.txt, nil, Head)
title.Size = UDim2.new(1, -156, 1, 0); title.Position = UDim2.new(0, 32, 0, 0); title.ZIndex = 12

-- test-sender button (drawn as a + icon)
local testBtn = mk("TextButton", Head)
testBtn.Size = UDim2.new(0, 22, 0, 22); testBtn.AnchorPoint = Vector2.new(1, 0.5)
testBtn.Position = UDim2.new(1, -94, 0.5, 0); testBtn.BackgroundColor3 = K.bg3
testBtn.Text = ""; testBtn.BorderSizePixel = 0; testBtn.AutoButtonColor = false; testBtn.ZIndex = 13
corner(7, testBtn); local testBtnStroke = stroke(testBtn, K.bdr, 1, 0)
local tHbar = mk("Frame", testBtn); tHbar.Size = UDim2.new(0, 10, 0, 1.8)
tHbar.AnchorPoint = Vector2.new(0.5, 0.5); tHbar.Position = UDim2.new(0.5, 0, 0.5, 0)
tHbar.BackgroundColor3 = K.txt2; tHbar.BorderSizePixel = 0; tHbar.ZIndex = 14; corner(1, tHbar)
local tVbar = mk("Frame", testBtn); tVbar.Size = UDim2.new(0, 1.8, 0, 10)
tVbar.AnchorPoint = Vector2.new(0.5, 0.5); tVbar.Position = UDim2.new(0.5, 0, 0.5, 0)
tVbar.BackgroundColor3 = K.txt2; tVbar.BorderSizePixel = 0; tVbar.ZIndex = 14; corner(1, tVbar)
testBtn.MouseEnter:Connect(function() tw(testBtn, 0.1, {BackgroundColor3 = K.bg4}); tw(testBtnStroke, 0.1, {Color = K.acc}) end)
testBtn.MouseLeave:Connect(function() tw(testBtn, 0.1, {BackgroundColor3 = K.bg3}); tw(testBtnStroke, 0.1, {Color = K.bdr}) end)

-- feed button (drawn as a list icon: dot + line rows)
local feedBtn = mk("TextButton", Head)
feedBtn.Size = UDim2.new(0, 22, 0, 22); feedBtn.AnchorPoint = Vector2.new(1, 0.5)
feedBtn.Position = UDim2.new(1, -66, 0.5, 0); feedBtn.BackgroundColor3 = K.bg3
feedBtn.Text = ""; feedBtn.BorderSizePixel = 0; feedBtn.AutoButtonColor = false; feedBtn.ZIndex = 13
corner(7, feedBtn); local feedBtnStroke = stroke(feedBtn, K.bdr, 1, 0)
for i = 0, 2 do
    local dot = mk("Frame", feedBtn)
    dot.Size = UDim2.new(0, 2.5, 0, 2.5); dot.AnchorPoint = Vector2.new(0, 0.5)
    dot.Position = UDim2.new(0, 5, 0.5, (i-1)*4); dot.BackgroundColor3 = K.txt2
    dot.BorderSizePixel = 0; dot.ZIndex = 14; corner(2, dot)
    local ln = mk("Frame", feedBtn)
    ln.Size = UDim2.new(0, 8, 0, 1.6); ln.AnchorPoint = Vector2.new(0, 0.5)
    ln.Position = UDim2.new(0, 9, 0.5, (i-1)*4); ln.BackgroundColor3 = K.txt2
    ln.BorderSizePixel = 0; ln.ZIndex = 14; corner(1, ln)
end
feedBtn.MouseEnter:Connect(function() tw(feedBtn, 0.1, {BackgroundColor3 = K.bg4}); tw(feedBtnStroke, 0.1, {Color = K.acc}) end)
feedBtn.MouseLeave:Connect(function() tw(feedBtn, 0.1, {BackgroundColor3 = K.bg3}); tw(feedBtnStroke, 0.1, {Color = K.bdr}) end)

-- gear / settings button (drawn as a clean 3-line menu icon)
local gear = mk("TextButton", Head)
gear.Size = UDim2.new(0, 22, 0, 22); gear.AnchorPoint = Vector2.new(1, 0.5)
gear.Position = UDim2.new(1, -38, 0.5, 0); gear.BackgroundColor3 = K.bg3
gear.Text = ""; gear.BorderSizePixel = 0; gear.AutoButtonColor = false; gear.ZIndex = 13
corner(7, gear); local gearStroke = stroke(gear, K.bdr, 1, 0)
for i = 0, 2 do
    local ln = mk("Frame", gear)
    ln.Size = UDim2.new(0, 11, 0, 1.6); ln.AnchorPoint = Vector2.new(0.5, 0.5)
    ln.Position = UDim2.new(0.5, 0, 0.5, (i-1)*4); ln.BackgroundColor3 = K.txt2
    ln.BorderSizePixel = 0; ln.ZIndex = 14; corner(1, ln)
end
gear.MouseEnter:Connect(function() tw(gear, 0.1, {BackgroundColor3 = K.bg4}); tw(gearStroke, 0.1, {Color = K.acc}) end)
gear.MouseLeave:Connect(function() tw(gear, 0.1, {BackgroundColor3 = K.bg3}); tw(gearStroke, 0.1, {Color = K.bdr}) end)

local close = mk("TextButton", Head)
close.Size = UDim2.new(0, 22, 0, 22); close.AnchorPoint = Vector2.new(1, 0.5)
close.Position = UDim2.new(1, -10, 0.5, 0); close.BackgroundColor3 = K.bg3
close.TextColor3 = K.txt2; close.Font = F.bold; close.TextSize = 11
close.Text = "X"; close.BorderSizePixel = 0; close.AutoButtonColor = false; close.ZIndex = 13
corner(11, close); stroke(close, K.bdr, 1, 0)
close.MouseEnter:Connect(function() tw(close, 0.1, {BackgroundColor3 = K.err, TextColor3 = K.txt}) end)
close.MouseLeave:Connect(function() tw(close, 0.1, {BackgroundColor3 = K.bg3, TextColor3 = K.txt2}) end)
close.MouseButton1Click:Connect(function() Main.Visible = false end)

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

local boxLbl = label("CODE", 9, F.black, K.accDim, nil, boxCard)
boxLbl.Size = UDim2.new(1, -18, 0, 10); boxLbl.Position = UDim2.new(0, 10, 0, 5); boxLbl.ZIndex = 13

local CodeBox = mk("TextBox", boxCard)
CodeBox.Size = UDim2.new(1, -18, 0, 28); CodeBox.Position = UDim2.new(0, 9, 1, -32)
CodeBox.BackgroundColor3 = K.input; CodeBox.BorderSizePixel = 0
CodeBox.PlaceholderText = "type code here..."
CodeBox.PlaceholderColor3 = Color3.fromRGB(110, 112, 122)
CodeBox.Text = ""; CodeBox.TextColor3 = K.txt
CodeBox.Font = F.black; CodeBox.TextSize = 15
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
cCopy.Font = F.black; cCopy.TextSize = 12
cCopy.AutoButtonColor = false; cCopy.ZIndex = 13
corner(6, cCopy); stroke(cCopy, K.bdr, 1.2, 0.1)
cCopy.MouseEnter:Connect(function() tw(cCopy, 0.1, {BackgroundColor3 = K.bg4, TextColor3 = K.accHov}) end)
cCopy.MouseLeave:Connect(function() tw(cCopy, 0.1, {BackgroundColor3 = K.bg2, TextColor3 = K.txt}) end)

local cRedeem = mk("TextButton", btnRow)
cRedeem.Size = UDim2.new(0.60, -4, 1, 0); cRedeem.Position = UDim2.new(0.40, 4, 0, 0)
cRedeem.BackgroundColor3 = K.acc; cRedeem.BorderSizePixel = 0
cRedeem.Text = "REDEEM"; cRedeem.TextColor3 = Color3.fromRGB(18, 18, 22)
cRedeem.Font = F.black; cRedeem.TextSize = 13
cRedeem.AutoButtonColor = false; cRedeem.ZIndex = 13
corner(6, cRedeem); stroke(cRedeem, K.accHov, 1.2, 0.4)
cRedeem.MouseEnter:Connect(function() tw(cRedeem, 0.08, {BackgroundColor3 = K.accHov}) end)
cRedeem.MouseLeave:Connect(function() tw(cRedeem, 0.08, {BackgroundColor3 = K.acc}) end)

-- MONITOR toggle row (key hint reflects the current bind)
local monRow = mk("Frame", content)
monRow.Size = UDim2.new(1, 0, 0, 28); monRow.Position = UDim2.new(0, 0, 0, 96)
monRow.BackgroundColor3 = K.bg2; monRow.BackgroundTransparency = 0.08
monRow.BorderSizePixel = 0; monRow.ZIndex = 12
corner(7, monRow); stroke(monRow, K.line, 1, 0.3)

local monLbl = label("LISTEN", 10, F.bold, K.txt2, nil, monRow)
monLbl.Size = UDim2.new(1, -120, 1, 0); monLbl.Position = UDim2.new(0, 10, 0, 0); monLbl.ZIndex = 13

local keyHint = mk("Frame", monRow)
keyHint.Size = UDim2.new(0, 26, 0, 16); keyHint.AnchorPoint = Vector2.new(1, 0.5)
keyHint.Position = UDim2.new(1, -52, 0.5, 0); keyHint.BackgroundColor3 = K.bg4
keyHint.BorderSizePixel = 0; keyHint.ZIndex = 13; corner(4, keyHint); stroke(keyHint, K.bdr, 1, 0.2)
local keyHintLbl = label("F", 9, F.black, K.txt, Enum.TextXAlignment.Center, keyHint)
keyHintLbl.Size = UDim2.new(1,0,1,0); keyHintLbl.ZIndex = 14

local pill = mk("Frame", monRow); pill.Size = UDim2.new(0, 34, 0, 16)
pill.AnchorPoint = Vector2.new(1, 0.5); pill.Position = UDim2.new(1, -10, 0.5, 0)
pill.BackgroundColor3 = K.txt3; pill.BorderSizePixel = 0; pill.ZIndex = 13; corner(8, pill)
local pdot = mk("Frame", pill); pdot.Size = UDim2.new(0, 12, 0, 12)
pdot.Position = UDim2.new(0, 2, 0.5, -6); pdot.BackgroundColor3 = K.txt
pdot.BorderSizePixel = 0; pdot.ZIndex = 14; corner(6, pdot)
local monBtn = mk("TextButton", monRow); monBtn.Size = UDim2.new(1, 0, 1, 0)
monBtn.BackgroundTransparency = 1; monBtn.Text = ""; monBtn.ZIndex = 15

-- INSTA REDEEM toggle row (wires into autoRedeem)
local instaRow = mk("Frame", content)
instaRow.Size = UDim2.new(1, 0, 0, 24); instaRow.Position = UDim2.new(0, 0, 0, 128)
instaRow.BackgroundColor3 = K.bg2; instaRow.BackgroundTransparency = 0.08
instaRow.BorderSizePixel = 0; instaRow.ZIndex = 12
corner(7, instaRow); stroke(instaRow, K.line, 1, 0.3)
local instaLbl = label("INSTA REDEEM", 10, F.bold, K.txt2, nil, instaRow)
instaLbl.Size = UDim2.new(1, -56, 1, 0); instaLbl.Position = UDim2.new(0, 10, 0, 0); instaLbl.ZIndex = 13
local ipill = mk("Frame", instaRow); ipill.Size = UDim2.new(0, 34, 0, 16)
ipill.AnchorPoint = Vector2.new(1, 0.5); ipill.Position = UDim2.new(1, -10, 0.5, 0)
ipill.BackgroundColor3 = K.txt3; ipill.BorderSizePixel = 0; ipill.ZIndex = 13; corner(8, ipill)
local idot = mk("Frame", ipill); idot.Size = UDim2.new(0, 12, 0, 12)
idot.Position = UDim2.new(0, 2, 0.5, -6); idot.BackgroundColor3 = K.txt
idot.BorderSizePixel = 0; idot.ZIndex = 14; corner(6, idot)
local ibtn = mk("TextButton", instaRow); ibtn.Size = UDim2.new(1, 0, 1, 0)
ibtn.BackgroundTransparency = 1; ibtn.Text = ""; ibtn.ZIndex = 15
local function setInsta(v)
    autoRedeem = v
    tw(ipill, 0.15, {BackgroundColor3 = v and K.acc or K.txt3})
    tw(idot, 0.15, {Position = UDim2.new(0, v and 20 or 2, 0.5, -6)}, Enum.EasingStyle.Back)
    tw(instaLbl, 0.15, {TextColor3 = v and K.accHov or K.txt2})
end
ibtn.MouseButton1Click:Connect(function() setInsta(not autoRedeem) end)
setInsta(autoRedeem)

-- status
local cStatus = mk("Frame", content)
cStatus.Size = UDim2.new(1, 0, 0, 50); cStatus.Position = UDim2.new(0, 0, 0, 158)
cStatus.BackgroundColor3 = K.bg2; cStatus.BackgroundTransparency = 0.08
cStatus.BorderSizePixel = 0; cStatus.ZIndex = 12
corner(7, cStatus); stroke(cStatus, K.line, 1, 0.3)

local cStatusHdr = label("STATUS", 8, F.black, K.accDim, nil, cStatus)
cStatusHdr.Size = UDim2.new(1, -18, 0, 10); cStatusHdr.Position = UDim2.new(0, 10, 0, 5); cStatusHdr.ZIndex = 13

local cStatusDot = mk("Frame", cStatus)
cStatusDot.Size = UDim2.new(0, 7, 0, 7); cStatusDot.AnchorPoint = Vector2.new(0, 0.5)
cStatusDot.Position = UDim2.new(0, 10, 0, 30); cStatusDot.BackgroundColor3 = K.txt3
cStatusDot.BorderSizePixel = 0; cStatusDot.ZIndex = 13; corner(50, cStatusDot)

local cStatusLbl = label("type a code, or press the key to listen.", 11, F.bold, K.txt, nil, cStatus)
cStatusLbl.Size = UDim2.new(1, -30, 0, 26); cStatusLbl.Position = UDim2.new(0, 22, 0, 17)
cStatusLbl.TextWrapped = true; cStatusLbl.TextYAlignment = Enum.TextYAlignment.Center; cStatusLbl.ZIndex = 13

local function setCStatus(text, kind)
    cStatusLbl.Text = text
    if kind == "ok" then cStatusLbl.TextColor3 = K.ok; cStatusDot.BackgroundColor3 = K.ok
    elseif kind == "err" then cStatusLbl.TextColor3 = K.err; cStatusDot.BackgroundColor3 = K.err
    elseif kind == "busy" then cStatusLbl.TextColor3 = K.accHov; cStatusDot.BackgroundColor3 = K.acc
    elseif kind == "wait" then cStatusLbl.TextColor3 = K.amber; cStatusDot.BackgroundColor3 = K.amber
    else cStatusLbl.TextColor3 = K.txt; cStatusDot.BackgroundColor3 = K.txt3 end
end

-- ── Redeem logic ─────────────────────────────────────────────────
local cBusy = false
local function runRedeem(code, doType)
    if not code or code == "" then setCStatus("no code yet.", "err"); return end
    if doType then CodeBox.Text = code end
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
    task.spawn(function() runRedeem(code, false); cBusy = false end)
end
cRedeem.MouseButton1Click:Connect(fireCustom)
CodeBox.FocusLost:Connect(function(enter) if enter then fireCustom() end end)

-- ── Listen / collect logic ───────────────────────────────────────
local function caseVariants(code)
    if caseMode == "UPPER" then return { code:upper() }
    elseif caseMode == "lower" then return { code:lower() }
    else return { code:upper(), code:lower() } end
end

local function targetWords() return rawMode and 1 or wordCount end
local function resetCollect() collectBuffer = {}; seenAttempts = {} end

local function setMonitor(v)
    monitorOn = v
    tw(pill, 0.15, {BackgroundColor3 = v and K.acc or K.txt3})
    tw(pdot, 0.15, {Position = UDim2.new(0, v and 20 or 2, 0.5, -6)}, Enum.EasingStyle.Back)
    tw(monLbl, 0.15, {TextColor3 = v and K.accHov or K.txt2})
    tw(Main, 0.15, {BackgroundTransparency = v and 0.06 or 0.12})
    if v then resetCollect(); setCStatus(("listening… 0/%d"):format(targetWords()), "wait")
    else setCStatus("listen off.", "idle") end
end
monBtn.MouseButton1Click:Connect(function() setMonitor(not monitorOn) end)

-- redeem an assembled code (RAW = keep exact case; else apply the CASE setting)
local function fireAssembled(code)
    local variants = rawMode and { code } or caseVariants(code)
    if autoType then CodeBox.Text = variants[1] end
    if autoRedeem then
        task.spawn(function()
            for _, v in ipairs(variants) do
                if not seenAttempts[v] then seenAttempts[v] = true; runRedeem(v, autoType) end
            end
        end)
    else
        setCStatus("collected: " .. variants[1] .. " — auto-redeem off", "ok")
    end
end

-- ══ SETTINGS PANEL ═══════════════════════════════════════════════
local SW, SH = 220, 224
local Settings = mk("Frame", SG); Settings.Name = "Settings"
Settings.Size = UDim2.new(0, SW, 0, SH)
Settings.Position = UDim2.new(1, -PW - 24 - SW - 12, 0.5, -SH/2)
Settings.BackgroundColor3 = K.bg; Settings.BackgroundTransparency = 0.12
Settings.BorderSizePixel = 0; Settings.ClipsDescendants = true; Settings.ZIndex = 20
Settings.Visible = false; corner(14, Settings)
stroke(Settings, K.bdr, 1.4, 0.25)

local sHead = mk("Frame", Settings)
sHead.Size = UDim2.new(1, 0, 0, 32); sHead.BackgroundColor3 = K.bg1
sHead.BackgroundTransparency = 0.08; sHead.BorderSizePixel = 0; sHead.ZIndex = 21
corner(14, sHead)
local sHeadMask = mk("Frame", sHead); sHeadMask.Size = UDim2.new(1,0,0,10)
sHeadMask.Position = UDim2.new(0,0,1,-10); sHeadMask.BackgroundColor3 = K.bg1
sHeadMask.BackgroundTransparency = 0.08; sHeadMask.BorderSizePixel = 0; sHeadMask.ZIndex = 21
local sTitle = label("SETTINGS", 11, F.black, K.txt, nil, sHead)
sTitle.Size = UDim2.new(1, -44, 1, 0); sTitle.Position = UDim2.new(0, 12, 0, 0); sTitle.ZIndex = 22
local sClose = mk("TextButton", sHead)
sClose.Size = UDim2.new(0, 20, 0, 20); sClose.AnchorPoint = Vector2.new(1, 0.5)
sClose.Position = UDim2.new(1, -8, 0.5, 0); sClose.BackgroundColor3 = K.bg3
sClose.TextColor3 = K.txt2; sClose.Font = F.bold; sClose.TextSize = 10
sClose.Text = "X"; sClose.BorderSizePixel = 0; sClose.AutoButtonColor = false; sClose.ZIndex = 23
corner(10, sClose); stroke(sClose, K.bdr, 1, 0)
sClose.MouseEnter:Connect(function() tw(sClose, 0.1, {BackgroundColor3 = K.err, TextColor3 = K.txt}) end)
sClose.MouseLeave:Connect(function() tw(sClose, 0.1, {BackgroundColor3 = K.bg3, TextColor3 = K.txt2}) end)
sClose.MouseButton1Click:Connect(function() Settings.Visible = false end)
attachDrag(sHead, Settings)

local sBody = mk("Frame", Settings)
sBody.Size = UDim2.new(1, -20, 1, -42); sBody.Position = UDim2.new(0, 10, 0, 38)
sBody.BackgroundTransparency = 1; sBody.ZIndex = 21

local function rowFrame(y, h)
    local r = mk("Frame", sBody)
    r.Size = UDim2.new(1, 0, 0, h); r.Position = UDim2.new(0, 0, 0, y)
    r.BackgroundColor3 = K.bg2; r.BackgroundTransparency = 0.08
    r.BorderSizePixel = 0; r.ZIndex = 22; corner(7, r); stroke(r, K.line, 1, 0.3)
    return r
end

-- keybind row
local kRow = rowFrame(0, 30)
local kLbl = label("KEYBIND", 10, F.bold, K.txt2, nil, kRow)
kLbl.Size = UDim2.new(1, -80, 1, 0); kLbl.Position = UDim2.new(0, 10, 0, 0); kLbl.ZIndex = 23
local keyBtn = mk("TextButton", kRow)
keyBtn.Size = UDim2.new(0, 62, 0, 20); keyBtn.AnchorPoint = Vector2.new(1, 0.5)
keyBtn.Position = UDim2.new(1, -8, 0.5, 0); keyBtn.BackgroundColor3 = K.bg4
keyBtn.Text = bindKey.Name; keyBtn.TextColor3 = K.txt
keyBtn.Font = F.bold; keyBtn.TextSize = 10; keyBtn.AutoButtonColor = false; keyBtn.ZIndex = 23
corner(5, keyBtn); local keyBtnStroke = stroke(keyBtn, K.bdr, 1, 0.1)
keyBtn.MouseEnter:Connect(function() if not rebinding then tw(keyBtnStroke, 0.1, {Color = K.acc, Transparency = 0}) end end)
keyBtn.MouseLeave:Connect(function() if not rebinding then tw(keyBtnStroke, 0.1, {Color = K.bdr, Transparency = 0.1}) end end)
keyBtn.MouseButton1Click:Connect(function()
    rebinding = true
    keyBtn.Text = "press key..."; keyBtn.TextColor3 = K.amber
    tw(keyBtnStroke, 0.1, {Color = K.amber, Transparency = 0})
end)

-- helper: toggle row with pill
local function makeToggleRow(y, text, default, onChange)
    local r = rowFrame(y, 30)
    local lb = label(text, 10, F.bold, K.txt2, nil, r)
    lb.Size = UDim2.new(1, -56, 1, 0); lb.Position = UDim2.new(0, 10, 0, 0); lb.ZIndex = 23
    local p = mk("Frame", r); p.Size = UDim2.new(0, 34, 0, 16)
    p.AnchorPoint = Vector2.new(1, 0.5); p.Position = UDim2.new(1, -10, 0.5, 0)
    p.BackgroundColor3 = K.txt3; p.BorderSizePixel = 0; p.ZIndex = 23; corner(8, p)
    local d = mk("Frame", p); d.Size = UDim2.new(0, 12, 0, 12)
    d.Position = UDim2.new(0, 2, 0.5, -6); d.BackgroundColor3 = K.txt
    d.BorderSizePixel = 0; d.ZIndex = 24; corner(6, d)
    local b = mk("TextButton", r); b.Size = UDim2.new(1, 0, 1, 0)
    b.BackgroundTransparency = 1; b.Text = ""; b.ZIndex = 25
    local state = default
    local function apply()
        tw(p, 0.15, {BackgroundColor3 = state and K.acc or K.txt3})
        tw(d, 0.15, {Position = UDim2.new(0, state and 20 or 2, 0.5, -6)}, Enum.EasingStyle.Back)
    end
    apply()
    b.MouseButton1Click:Connect(function() state = not state; apply(); if onChange then onChange(state) end end)
end
makeToggleRow(34, "AUTO TYPE", autoType, function(v) autoType = v end)
makeToggleRow(68, "RAW WORD",  rawMode,  function(v) rawMode = v; resetCollect() end)

-- segmented row helper (used for CASE and WORDS)
local function makeSegRow(y, labelText, opts, default, onChange)
    local row = rowFrame(y, 30)
    local lb = label(labelText, 10, F.bold, K.txt2, nil, row)
    lb.Size = UDim2.new(0, 60, 1, 0); lb.Position = UDim2.new(0, 10, 0, 0); lb.ZIndex = 23
    local host = mk("Frame", row)
    host.AnchorPoint = Vector2.new(1, 0.5); host.Position = UDim2.new(1, -8, 0.5, 0)
    host.Size = UDim2.new(0, 132, 0, 20); host.BackgroundTransparency = 1; host.ZIndex = 23
    local btns, n = {}, #opts
    local function sel(opt)
        for o, b in pairs(btns) do
            local on = (o == opt)
            tw(b, 0.12, {BackgroundColor3 = on and K.acc or K.bg3})
            b.TextColor3 = on and Color3.fromRGB(18,18,22) or K.txt2
        end
        if onChange then onChange(opt) end
    end
    for i, opt in ipairs(opts) do
        local b = mk("TextButton", host)
        b.Size = UDim2.new(1/n, -3, 1, 0); b.Position = UDim2.new((i-1)/n, (i-1)*1.5, 0, 0)
        b.BackgroundColor3 = K.bg3; b.BorderSizePixel = 0
        b.Text = tostring(opt); b.Font = F.bold; b.TextSize = 9
        b.TextColor3 = K.txt2; b.AutoButtonColor = false; b.ZIndex = 24
        corner(5, b); btns[opt] = b
        b.MouseButton1Click:Connect(function() sel(opt) end)
    end
    sel(default)
end
makeSegRow(102, "CASE",  {"UPPER", "lower", "BOTH"}, caseMode, function(o) caseMode = o end)
makeSegRow(136, "WORDS", {"1", "2", "3"}, tostring(wordCount), function(o)
    wordCount = tonumber(o) or 1
    resetCollect()              -- reset the word buffer when the setting changes
end)

-- gear opens settings beside Main
gear.MouseButton1Click:Connect(function()
    if Settings.Visible then Settings.Visible = false; return end
    local mp = Main.Position
    Settings.Position = UDim2.new(mp.X.Scale, mp.X.Offset - SW - 12, mp.Y.Scale, mp.Y.Offset + (PH - SH)/2)
    Settings.Visible = true
end)

-- ══ LIVE FEED ════════════════════════════════════════════════════
-- Logs every announcement caught off the notify remote, newest on top.
local FW, FH = 306, 300
local FeedWin = mk("Frame", SG); FeedWin.Name = "Feed"
FeedWin.Size = UDim2.new(0, FW, 0, FH)
FeedWin.Position = UDim2.new(1, -PW - 24 - FW - 12, 0.5, -FH/2)
FeedWin.BackgroundColor3 = K.bg; FeedWin.BackgroundTransparency = 0.12
FeedWin.BorderSizePixel = 0; FeedWin.ClipsDescendants = true; FeedWin.ZIndex = 20
FeedWin.Visible = false; corner(14, FeedWin)
stroke(FeedWin, K.bdr, 1.4, 0.25)

local fHead = mk("Frame", FeedWin)
fHead.Size = UDim2.new(1, 0, 0, 32); fHead.BackgroundColor3 = K.bg1
fHead.BackgroundTransparency = 0.08; fHead.BorderSizePixel = 0; fHead.ZIndex = 21
corner(14, fHead)
local fHeadMask = mk("Frame", fHead); fHeadMask.Size = UDim2.new(1,0,0,10)
fHeadMask.Position = UDim2.new(0,0,1,-10); fHeadMask.BackgroundColor3 = K.bg1
fHeadMask.BackgroundTransparency = 0.08; fHeadMask.BorderSizePixel = 0; fHeadMask.ZIndex = 21
local fLiveDot = mk("Frame", fHead)
fLiveDot.Size = UDim2.new(0, 7, 0, 7); fLiveDot.AnchorPoint = Vector2.new(0, 0.5)
fLiveDot.Position = UDim2.new(0, 12, 0.5, 0); fLiveDot.BackgroundColor3 = K.txt3
fLiveDot.BorderSizePixel = 0; fLiveDot.ZIndex = 22; corner(50, fLiveDot)
local fTitle = label("LIVE FEED", 11, F.black, K.txt, nil, fHead)
fTitle.Size = UDim2.new(0, 100, 1, 0); fTitle.Position = UDim2.new(0, 26, 0, 0); fTitle.ZIndex = 22
local fCountLbl = label("0 caught", 9, F.bold, K.txt3, Enum.TextXAlignment.Right, fHead)
fCountLbl.Size = UDim2.new(0, 60, 1, 0); fCountLbl.Position = UDim2.new(1, -146, 0, 0); fCountLbl.ZIndex = 22
local fClear = mk("TextButton", fHead)
fClear.Size = UDim2.new(0, 44, 0, 18); fClear.AnchorPoint = Vector2.new(1, 0.5)
fClear.Position = UDim2.new(1, -34, 0.5, 0); fClear.BackgroundColor3 = K.bg3
fClear.Text = "CLEAR"; fClear.TextColor3 = K.txt2; fClear.Font = F.bold; fClear.TextSize = 8
fClear.BorderSizePixel = 0; fClear.AutoButtonColor = false; fClear.ZIndex = 23
corner(5, fClear); stroke(fClear, K.bdr, 1, 0.2)
fClear.MouseEnter:Connect(function() tw(fClear, 0.1, {BackgroundColor3 = K.bg4, TextColor3 = K.accHov}) end)
fClear.MouseLeave:Connect(function() tw(fClear, 0.1, {BackgroundColor3 = K.bg3, TextColor3 = K.txt2}) end)
local fClose = mk("TextButton", fHead)
fClose.Size = UDim2.new(0, 20, 0, 20); fClose.AnchorPoint = Vector2.new(1, 0.5)
fClose.Position = UDim2.new(1, -8, 0.5, 0); fClose.BackgroundColor3 = K.bg3
fClose.TextColor3 = K.txt2; fClose.Font = F.bold; fClose.TextSize = 10
fClose.Text = "X"; fClose.BorderSizePixel = 0; fClose.AutoButtonColor = false; fClose.ZIndex = 23
corner(10, fClose); stroke(fClose, K.bdr, 1, 0)
fClose.MouseEnter:Connect(function() tw(fClose, 0.1, {BackgroundColor3 = K.err, TextColor3 = K.txt}) end)
fClose.MouseLeave:Connect(function() tw(fClose, 0.1, {BackgroundColor3 = K.bg3, TextColor3 = K.txt2}) end)
fClose.MouseButton1Click:Connect(function() FeedWin.Visible = false end)
attachDrag(fHead, FeedWin)

local feedScroll = mk("ScrollingFrame", FeedWin)
feedScroll.Size = UDim2.new(1, -16, 1, -40); feedScroll.Position = UDim2.new(0, 8, 0, 36)
feedScroll.BackgroundTransparency = 1; feedScroll.BorderSizePixel = 0
feedScroll.ScrollBarThickness = 3; feedScroll.ScrollBarImageColor3 = K.accDim
feedScroll.ScrollBarImageTransparency = 0.3; feedScroll.ZIndex = 21
feedScroll.CanvasSize = UDim2.new(0,0,0,0); feedScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
feedScroll.ScrollingDirection = Enum.ScrollingDirection.Y
local feedLay = mk("UIListLayout", feedScroll)
feedLay.SortOrder = Enum.SortOrder.LayoutOrder; feedLay.Padding = UDim.new(0, 6)

local fEmpty = label("waiting for announcements…", 10, F.med, K.txt3, Enum.TextXAlignment.Center, feedScroll)
fEmpty.Size = UDim2.new(1, 0, 0, 40); fEmpty.LayoutOrder = 999; fEmpty.ZIndex = 22

local feedCards, feedOrder, MAX_FEED = {}, 0, 40

local function addFeedEntry(text, code)
    if fEmpty then fEmpty:Destroy(); fEmpty = nil end
    feedOrder += 1
    fCountLbl.Text = feedOrder .. " caught"

    local card = mk("Frame", feedScroll)
    card.Size = UDim2.new(1, 0, 0, 0); card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = K.bg3; card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0; card.LayoutOrder = -feedOrder; card.ZIndex = 22
    corner(8, card); stroke(card, code and K.bdr or K.line, 1, code and 0.1 or 0.4)
    local cpad = mk("UIPadding", card)
    cpad.PaddingTop = UDim.new(0,8); cpad.PaddingBottom = UDim.new(0,8)
    cpad.PaddingLeft = UDim.new(0,9); cpad.PaddingRight = UDim.new(0,9)
    local clay = mk("UIListLayout", card)
    clay.SortOrder = Enum.SortOrder.LayoutOrder; clay.Padding = UDim.new(0, 5)

    -- header line: source dot + NOTIFY + time
    local hrow = mk("Frame", card)
    hrow.Size = UDim2.new(1, 0, 0, 12); hrow.BackgroundTransparency = 1; hrow.LayoutOrder = 1; hrow.ZIndex = 23
    local sdot = mk("Frame", hrow)
    sdot.Size = UDim2.new(0, 6, 0, 6); sdot.AnchorPoint = Vector2.new(0, 0.5)
    sdot.Position = UDim2.new(0, 0, 0.5, 0); sdot.BackgroundColor3 = code and K.acc or K.txt3
    sdot.BorderSizePixel = 0; sdot.ZIndex = 24; corner(50, sdot)
    local src = label("NOTIFY", 8, F.black, K.accDim, nil, hrow)
    src.Size = UDim2.new(0, 60, 1, 0); src.Position = UDim2.new(0, 12, 0, 0); src.ZIndex = 24
    local tm = label(os.date("%H:%M:%S"), 8, F.med, K.txt3, Enum.TextXAlignment.Right, hrow)
    tm.Size = UDim2.new(0, 70, 1, 0); tm.Position = UDim2.new(1, -70, 0, 0); tm.ZIndex = 24

    -- message text
    local msg = label(text, 10, F.med, K.txt, nil, card)
    msg.Size = UDim2.new(1, 0, 0, 0); msg.AutomaticSize = Enum.AutomaticSize.Y
    msg.TextWrapped = true; msg.LayoutOrder = 2; msg.ZIndex = 23

    -- code chip + actions
    if code then
        local crow = mk("Frame", card)
        crow.Size = UDim2.new(1, 0, 0, 26); crow.BackgroundTransparency = 1; crow.LayoutOrder = 3; crow.ZIndex = 23
        local chip = mk("Frame", crow)
        chip.Size = UDim2.new(0.46, -4, 1, 0); chip.BackgroundColor3 = K.input
        chip.BorderSizePixel = 0; chip.ZIndex = 24; corner(5, chip); stroke(chip, K.bdr, 1, 0.2)
        local chl = label(code, 11, F.black, K.accHov, Enum.TextXAlignment.Center, chip)
        chl.Size = UDim2.new(1, -8, 1, 0); chl.Position = UDim2.new(0, 4, 0, 0); chl.ZIndex = 25

        local cp = mk("TextButton", crow)
        cp.Size = UDim2.new(0.24, -4, 1, 0); cp.Position = UDim2.new(0.52, 0, 0, 0)
        cp.BackgroundColor3 = K.bg2; cp.BorderSizePixel = 0; cp.Text = "COPY"
        cp.TextColor3 = K.txt2; cp.Font = F.bold; cp.TextSize = 9; cp.AutoButtonColor = false; cp.ZIndex = 24
        corner(5, cp); stroke(cp, K.bdr, 1, 0.2)
        cp.MouseButton1Click:Connect(function()
            local ok = copyText(code); cp.Text = ok and "OK" or "ERR"
            task.delay(0.7, function() if cp.Parent then cp.Text = "COPY" end end)
        end)

        local rd = mk("TextButton", crow)
        rd.Size = UDim2.new(0.24, -4, 1, 0); rd.Position = UDim2.new(0.76, 0, 0, 0)
        rd.BackgroundColor3 = K.acc; rd.BorderSizePixel = 0; rd.Text = "REDEEM"
        rd.TextColor3 = Color3.fromRGB(18,18,22); rd.Font = F.black; rd.TextSize = 9
        rd.AutoButtonColor = false; rd.ZIndex = 24; corner(5, rd)
        rd.MouseButton1Click:Connect(function()
            rd.Text = "…"; task.spawn(function() runRedeem(code, true); rd.Text = "REDEEM" end)
        end)
    end

    table.insert(feedCards, card)
    if #feedCards > MAX_FEED then
        local oldc = table.remove(feedCards, 1)
        if oldc then oldc:Destroy() end
    end
end

fClear.MouseButton1Click:Connect(function()
    for _, c in ipairs(feedCards) do c:Destroy() end
    feedCards = {}; feedOrder = 0; fCountLbl.Text = "0 caught"
    if not fEmpty then
        fEmpty = label("waiting for announcements…", 10, F.med, K.txt3, Enum.TextXAlignment.Center, feedScroll)
        fEmpty.Size = UDim2.new(1, 0, 0, 40); fEmpty.LayoutOrder = 999; fEmpty.ZIndex = 22
    end
end)

-- feed button opens the feed beside Main
feedBtn.MouseButton1Click:Connect(function()
    if FeedWin.Visible then FeedWin.Visible = false; return end
    local mp = Main.Position
    FeedWin.Position = UDim2.new(mp.X.Scale, mp.X.Offset - FW - 12, mp.Y.Scale, mp.Y.Offset + (PH - FH)/2)
    FeedWin.Visible = true
end)

-- ══ TEST SENDER ══════════════════════════════════════════════════
-- Type anything and "send" it as a fake announcement (local only) — it
-- runs through the same handler + feed, so you can test the listen flow.
local TSW, TSH = 286, 150
local TestWin = mk("Frame", SG); TestWin.Name = "TestSender"
TestWin.Size = UDim2.new(0, TSW, 0, TSH)
TestWin.Position = UDim2.new(0.5, -TSW/2, 0.5, -TSH/2)
TestWin.BackgroundColor3 = K.bg; TestWin.BackgroundTransparency = 0.12
TestWin.BorderSizePixel = 0; TestWin.ClipsDescendants = true; TestWin.ZIndex = 20
TestWin.Visible = false; corner(14, TestWin)
stroke(TestWin, K.bdr, 1.4, 0.25)

local tHead = mk("Frame", TestWin)
tHead.Size = UDim2.new(1, 0, 0, 32); tHead.BackgroundColor3 = K.bg1
tHead.BackgroundTransparency = 0.08; tHead.BorderSizePixel = 0; tHead.ZIndex = 21
corner(14, tHead)
local tHeadMask = mk("Frame", tHead); tHeadMask.Size = UDim2.new(1,0,0,10)
tHeadMask.Position = UDim2.new(0,0,1,-10); tHeadMask.BackgroundColor3 = K.bg1
tHeadMask.BackgroundTransparency = 0.08; tHeadMask.BorderSizePixel = 0; tHeadMask.ZIndex = 21
local tTitle = label("TEST SENDER", 11, F.black, K.txt, nil, tHead)
tTitle.Size = UDim2.new(1, -44, 1, 0); tTitle.Position = UDim2.new(0, 12, 0, 0); tTitle.ZIndex = 22
local tCloseB = mk("TextButton", tHead)
tCloseB.Size = UDim2.new(0, 20, 0, 20); tCloseB.AnchorPoint = Vector2.new(1, 0.5)
tCloseB.Position = UDim2.new(1, -8, 0.5, 0); tCloseB.BackgroundColor3 = K.bg3
tCloseB.TextColor3 = K.txt2; tCloseB.Font = F.bold; tCloseB.TextSize = 10
tCloseB.Text = "X"; tCloseB.BorderSizePixel = 0; tCloseB.AutoButtonColor = false; tCloseB.ZIndex = 23
corner(10, tCloseB); stroke(tCloseB, K.bdr, 1, 0)
tCloseB.MouseEnter:Connect(function() tw(tCloseB, 0.1, {BackgroundColor3 = K.err, TextColor3 = K.txt}) end)
tCloseB.MouseLeave:Connect(function() tw(tCloseB, 0.1, {BackgroundColor3 = K.bg3, TextColor3 = K.txt2}) end)
tCloseB.MouseButton1Click:Connect(function() TestWin.Visible = false end)
attachDrag(tHead, TestWin)

local tHint = label("fires a real popup (local only) — type to test", 8, F.med, K.txt3, nil, TestWin)
tHint.Size = UDim2.new(1, -24, 0, 12); tHint.Position = UDim2.new(0, 12, 0, 38); tHint.ZIndex = 21

local tInput = mk("TextBox", TestWin)
tInput.Size = UDim2.new(1, -24, 0, 34); tInput.Position = UDim2.new(0, 12, 0, 54)
tInput.BackgroundColor3 = K.input; tInput.BorderSizePixel = 0
tInput.PlaceholderText = "type a word or message…"
tInput.PlaceholderColor3 = Color3.fromRGB(110,112,122)
tInput.Text = ""; tInput.TextColor3 = K.txt; tInput.Font = F.bold; tInput.TextSize = 13
tInput.ClearTextOnFocus = false; tInput.ZIndex = 22; tInput.TextXAlignment = Enum.TextXAlignment.Left
corner(6, tInput)
local tiPad = mk("UIPadding", tInput); tiPad.PaddingLeft = UDim.new(0,8); tiPad.PaddingRight = UDim.new(0,8)
local tiStroke = stroke(tInput, K.bdr, 1.2, 0.25)
tInput.Focused:Connect(function() tw(tiStroke, 0.12, {Color = K.acc, Transparency = 0.05}) end)
tInput.FocusLost:Connect(function() tw(tiStroke, 0.12, {Color = K.bdr, Transparency = 0.25}) end)

local tSend = mk("TextButton", TestWin)
tSend.Size = UDim2.new(0, 152, 0, 30); tSend.Position = UDim2.new(0, 12, 1, -38)
tSend.BackgroundColor3 = K.acc; tSend.BorderSizePixel = 0
tSend.Text = "SEND"; tSend.TextColor3 = Color3.fromRGB(18,18,22)
tSend.Font = F.black; tSend.TextSize = 11; tSend.AutoButtonColor = false; tSend.ZIndex = 22
corner(6, tSend); stroke(tSend, K.accHov, 1.2, 0.4)
tSend.MouseEnter:Connect(function() tw(tSend, 0.08, {BackgroundColor3 = K.accHov}) end)
tSend.MouseLeave:Connect(function() tw(tSend, 0.08, {BackgroundColor3 = K.acc}) end)

-- TEST CODE: fires a random code announcement so you can test auto-redeem
local tCode = mk("TextButton", TestWin)
tCode.Size = UDim2.new(0, 98, 0, 30); tCode.Position = UDim2.new(0, 176, 1, -38)
tCode.BackgroundColor3 = K.bg3; tCode.BorderSizePixel = 0
tCode.Text = "TEST CODE"; tCode.TextColor3 = K.txt
tCode.Font = F.black; tCode.TextSize = 10; tCode.AutoButtonColor = false; tCode.ZIndex = 22
corner(6, tCode); stroke(tCode, K.bdr, 1.2, 0.2)
tCode.MouseEnter:Connect(function() tw(tCode, 0.1, {BackgroundColor3 = K.bg4, TextColor3 = K.accHov}) end)
tCode.MouseLeave:Connect(function() tw(tCode, 0.1, {BackgroundColor3 = K.bg3, TextColor3 = K.txt}) end)

local function fireAnnouncement(txt)
    txt = (txt or ""):gsub("^%s+",""):gsub("%s+$","")
    if txt == "" then return end
    local re = NotifyRemote or _G.PhiNotifyRemote
    if re and typeof(firesignal) == "function" then
        firesignal(re.OnClientEvent, txt, 5.5, "Sounds.Sfx.Blop", "Top", 2678001507)  -- real popup + feed
    else
        handleAnnouncement("TEST", txt)          -- fallback: inject directly (no popup)
    end
end
local function sendTest()
    fireAnnouncement(tInput.Text)
    tInput.Text = ""; tInput:CaptureFocus()
end
tCode.MouseButton1Click:Connect(function()
    local code = "TESTCODE" .. tostring(math.random(1000, 9999))
    addFeedEntry("[test code] " .. code, code)
    fireAssembled(code)   -- runs the auto-redeem path: INSTA on -> redeems, off -> types
end)
tSend.MouseButton1Click:Connect(sendTest)
tInput.FocusLost:Connect(function(enter) if enter then sendTest() end end)

testBtn.MouseButton1Click:Connect(function()
    if TestWin.Visible then TestWin.Visible = false; return end
    local mp = Main.Position
    TestWin.Position = UDim2.new(mp.X.Scale, mp.X.Offset - TSW - 12, mp.Y.Scale, mp.Y.Offset)
    TestWin.Visible = true
    tInput:CaptureFocus()
end)

-- ── Keybind input (toggle monitor + rebind capture) ──────────────
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if rebinding then
        rebinding = false
        if input.KeyCode ~= Enum.KeyCode.Escape then bindKey = input.KeyCode end
        keyBtn.Text = bindKey.Name; keyBtn.TextColor3 = K.txt
        keyHintLbl.Text = bindKey.Name:sub(1, 3):upper()
        tw(keyBtnStroke, 0.1, {Color = K.bdr, Transparency = 0.1})
        return
    end
    if gpe then return end                       -- ignore while typing in the box
    if input.KeyCode == bindKey then
        setMonitor(not monitorOn)                -- F arms/disarms listening
    end
end)

-- ── Announcement handler ─────────────────────────────────────────
local function flashCatch()
    tw(cStatus, 0.06, {BackgroundColor3 = K.acc, BackgroundTransparency = 0.45})
    tw(cStatusDot, 0.06, {BackgroundColor3 = K.acc})
    task.delay(0.14, function()
        tw(cStatus, 0.35, {BackgroundColor3 = K.bg2, BackgroundTransparency = 0.08})
    end)
end

-- While listening (armed by F), collect words IN ORDER from each announcement
-- until we reach the target count, then join + insta-redeem. Words may all come
-- from one message ("the FIRST ..." -> theFIRST with WORDS=2) or across several
-- ("octo" .. "1234" -> octo1234). RAW = the first single word, exact case.
function handleAnnouncement(source, text, ...)
    local stripped = stripRich(tostring(text or "")); if stripped == "" then return end
    local feedChip
    if monitorOn then
        for _, w in ipairs(tokenize(stripped)) do
            collectBuffer[#collectBuffer + 1] = w
        end
        local target = targetWords()
        -- assemble the code-so-far and live-preview it into the CODE box
        local upto, parts = math.min(#collectBuffer, target), {}
        for i = 1, upto do parts[i] = collectBuffer[i] end
        local joined  = table.concat(parts)
        local preview = rawMode and joined or caseVariants(joined)[1]
        CodeBox.Text = preview
        if #collectBuffer >= target then
            feedChip = preview
            resetCollect()
            setMonitor(false)            -- one-shot: stop listening after a code
            lastCapturedCode = joined
            flashCatch()
            fireAssembled(joined)        -- 0-delay redeem (+ both case variants if BOTH)
        else
            setCStatus(("listening… %d/%d  (+%s)"):format(#collectBuffer, target, collectBuffer[#collectBuffer]), "wait")
        end
    end
    addFeedEntry(stripped, feedChip)              -- live feed: every announcement
end

-- ══ NOTIFY REMOTE (via NotificationController) ═══════════════════
-- The notify remote is the 'Notify' event owned by NotificationController.
-- The hash rotates but the controller's script name doesn't — so we pull
-- the live RemoteEvent straight out of its code and listen to ONLY it.
local function gatherRFs(root)
    local rfs = {}
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("RemoteFunction") then table.insert(rfs, d) end
    end
    return rfs
end

local function findNotifyRemote()
    local getinfo = debug and (debug.getinfo or debug.info)
    if not getinfo then return nil end

    -- A) the remote whose OnClientEvent handler lives in NotificationController
    if getconnections then
        for _, d in ipairs(Net:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                local ok, conns = pcall(getconnections, d.OnClientEvent)
                if ok and type(conns) == "table" then
                    for _, c in ipairs(conns) do
                        local fok, fn = pcall(function() return c.Function end)
                        if fok and type(fn) == "function" then
                            local iok, info = pcall(getinfo, fn)
                            if iok and type(info) == "table"
                               and tostring(info.short_src or info.source or ""):find("NotificationController", 1, true) then
                                return d
                            end
                        end
                    end
                end
            end
        end
    end

    -- B) fallback: scan NotificationController functions for a hash-named RemoteEvent
    if getgc then
        local getups    = (debug and debug.getupvalues) or getupvalues
        local getconsts = (debug and debug.getconstants) or getconstants
        local function pick(list, depth)
            for _, v in pairs(list) do
                if typeof(v) == "Instance" and v:IsA("RemoteEvent") and v.Name:match("^RE/%x+$") then
                    return v
                elseif type(v) == "table" and depth > 0 then
                    local r = pick(v, depth - 1); if r then return r end
                end
            end
        end
        for _, fn in ipairs(getgc(true)) do
            if type(fn) == "function" then
                local ok, info = pcall(getinfo, fn)
                if ok and type(info) == "table"
                   and tostring(info.short_src or info.source or ""):find("NotificationController", 1, true) then
                    if getups    then local k, ups = pcall(getups, fn);    if k then local r = pick(ups, 1); if r then return r end end end
                    if getconsts then local k, cs  = pcall(getconsts, fn); if k then local r = pick(cs, 1);  if r then return r end end end
                end
            end
        end
    end
    return nil
end

local function markLocked(re, how)
    NotifyRemote = re
    _G.PhiNotifyRemote = re
    mark.BackgroundColor3 = K.ok            -- header dot: green = locked
    fLiveDot.BackgroundColor3 = K.ok        -- feed dot: green = live
    print("[Phi] Notify locked (" .. how .. ") ->", re.Name)
end

-- primary: find & listen to ONLY the NotificationController remote
local nr = findNotifyRemote()
if nr then
    markLocked(nr, "NotificationController")
    nr.OnClientEvent:Connect(function(...) pcall(handleAnnouncement, "NOTIFY", (...)) end)
else
    -- fallback (only if debug tools are unavailable): identify by payload shape
    warn("[Phi] NotificationController scan unavailable — falling back to shape detection.")
    local POSITIONS = { Top=true, Bottom=true, Center=true, Centre=true, Middle=true,
                        Left=true, Right=true, TopRight=true, TopLeft=true, BottomRight=true }
    local function looksLikeAnnouncement(...)
        local a = table.pack(...)
        if a.n == 0 or typeof(a[1]) ~= "string" or #a[1] < 3 then return false end
        local hasSound, hasPos = false, false
        for i = 2, a.n do
            local v = a[i]
            if typeof(v) == "string" then
                if v:find("Sounds%.") or v:find("rbxassetid") then hasSound = true end
                if POSITIONS[v] then hasPos = true end
            end
        end
        return hasSound or hasPos
    end
    local function hookEvent(re)
        re.OnClientEvent:Connect(function(...)
            if NotifyRemote and NotifyRemote ~= re then return end
            if looksLikeAnnouncement(...) then
                if not NotifyRemote then markLocked(re, "shape") end
                pcall(handleAnnouncement, "NOTIFY", (...))
            end
        end)
    end
    for _, d in ipairs(Net:GetDescendants()) do
        if d:IsA("RemoteEvent") then hookEvent(d) end
    end
    Net.DescendantAdded:Connect(function(d) if d:IsA("RemoteEvent") then hookEvent(d) end end)
end

-- Redeem RemoteFunction — found by its readable name (no hooks, no spam)
for _, rf in ipairs(gatherRFs(Net)) do
    local n = rf.Name:lower()
    if n:find("redeem") or n:find("redemption") then RedeemRemote = rf; break end
end
if not RedeemRemote then
    warn("[Phi] Redeem remote not found by name — manual/auto redeem will be disabled.")
end

setCStatus("press " .. bindKey.Name .. " to listen, or type a code.", "idle")
print(("[Phi] v15 ready — notify=%s, redeem=%s")
    :format(NotifyRemote and NotifyRemote.Name or "NOT FOUND",
            RedeemRemote and RedeemRemote.Name or "learn-on-use"))
