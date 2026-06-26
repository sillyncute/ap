local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PG  = Player:WaitForChild("PlayerGui")
local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")

for _, n in ipairs({"CodeWatcher"}) do
    local old = PG:FindFirstChild(n); if old then old:Destroy() end
end

-- ===== CONFIG =====================================================
-- Preference order. RF returns the reward (nice popup); RE is fire-and-forget
-- (slightly faster, no return value). These event codes work through either.
local REDEEM_NAMES   = { "RF/RequestRedemption", "RE/StockEventService/Redeem" }
local REDEEM_EXISTING = true   -- also auto-redeem codes already live when you join
local MAX_TRIES       = 3      -- retries on transient (network) failure
-- ==================================================================

-- Net stores remotes by their full name (e.g. "RF/RequestRedemption"), so we
-- resolve directly instead of guessing marker/remote adjacency.
local REMOTE_CLASSES = {RemoteEvent = true, RemoteFunction = true, UnreliableRemoteEvent = true}
local function isRemote(o) return o and REMOTE_CLASSES[o.ClassName] end

local function deepFindRemote(name)
    local direct = Net:FindFirstChild(name)
    if isRemote(direct) then return direct end
    for _, d in ipairs(Net:GetDescendants()) do
        if d.Name == name and isRemote(d) then return d end
    end
end

local RedeemRemote
local function ensureRedeemRemote()
    if RedeemRemote and RedeemRemote.Parent then return RedeemRemote end
    local cached = _G.PhiRedeemRemote
    if typeof(cached) == "Instance" and cached.Parent and isRemote(cached) then
        RedeemRemote = cached
    else
        for _, n in ipairs(REDEEM_NAMES) do
            local r = deepFindRemote(n)
            if r then RedeemRemote = r break end
        end
    end
    if RedeemRemote then _G.PhiRedeemRemote = RedeemRemote end
    return RedeemRemote
end

local function describeReward(result)
    if type(result) ~= "table" then return nil end
    local keys = {"brainrot","Brainrot","reward","Reward","item","Item","unit","Unit",
                  "prize","Prize","granted","Granted","name","Name","display","Display"}
    for _, k in ipairs(keys) do
        local v = result[k]
        if type(v) == "string" and v ~= "" then return v end
        if type(v) == "table" then
            local nm = v.name or v.Name or v.displayName or v.DisplayName
            if type(nm) == "string" and nm ~= "" then return nm end
        end
    end
    local nested = result.data or result.Data or result.result or result.Result or result.rewards or result.Rewards
    if type(nested) == "table" then
        local r = describeReward(nested)
        if r then return r end
        if type(nested[1]) == "table" or type(nested[1]) == "string" then
            local r2 = describeReward(nested[1])
            if r2 then return r2 end
            if type(nested[1]) == "string" then return nested[1] end
        end
    end
    local ok, j = pcall(function() return HttpService:JSONEncode(result) end)
    if ok and #j <= 120 then return j end
    return nil
end

-- Only treat a table return as a rejection when the server actually says so.
-- A reward table with no explicit "success" field is a SUCCESS, not a reject.
local NEGATIVE = {"invalid","cooldown","already","expired","fail","not found","unknown","error","denied"}
local function looksFailed(result)
    if type(result) ~= "table" then return false end
    if result.success == false or result.Success == false then return true end
    for _, k in ipairs({"error","Error","err"}) do
        local v = result[k]
        if v ~= nil and v ~= false then return true end
    end
    for _, k in ipairs({"reason","Reason","message","Message","msg","status","Status"}) do
        local v = result[k]
        if type(v) == "string" then
            local lv = v:lower()
            for _, bad in ipairs(NEGATIVE) do if lv:find(bad, 1, true) then return true end end
        end
    end
    return false
end

-- returns: ok, result, hardFail
--   hardFail = true  -> server logically rejected it; do NOT retry
--   hardFail = false -> transient/network error; safe to retry
local function redeem(code)
    local remote = ensureRedeemRemote()
    if not remote then return false, "no remote", true end
    print("[CodeWatcher] Redeeming:", code)
    if remote:IsA("RemoteFunction") then
        local ok, result = pcall(function() return remote:InvokeServer(code) end)
        if not ok then
            warn("[CodeWatcher] ✗ Redeem error:", code, "->", tostring(result))
            return false, tostring(result), false
        end
        if type(result) == "table" and looksFailed(result) then
            warn("[CodeWatcher] ✗ Redeem rejected:", code, "| result:", result)
            return false, result, true
        end
        print("[CodeWatcher] ✓ Redeemed:", code, "| result:", result)
        return true, result, false
    else
        -- RemoteEvent / UnreliableRemoteEvent: fire-and-forget, optimistic
        local ok, err = pcall(function() remote:FireServer(code) end)
        if not ok then return false, tostring(err), false end
        print("[CodeWatcher] ✓ Fired (RE):", code)
        return true, nil, false
    end
end

local function copyText(s)
    for _, fn in ipairs({setclipboard, toclipboard, (syn and syn.write_clipboard)}) do
        if fn then local ok = pcall(fn, s); if ok then return true end end
    end
    return false
end

local function pickFont(getter, fallback)
    local ok, f = pcall(getter)
    if ok and typeof(f) == "EnumItem" then return f end
    return fallback
end
local F = {
    reg   = pickFont(function() return Enum.Font.BuilderSans end,          Enum.Font.Gotham),
    med   = pickFont(function() return Enum.Font.BuilderSansMedium end,    Enum.Font.GothamMedium),
    bold  = pickFont(function() return Enum.Font.BuilderSansBold end,      Enum.Font.GothamBold),
    black = pickFont(function() return Enum.Font.BuilderSansExtraBold end, Enum.Font.GothamBlack),
}

local K = {
    bg   = Color3.fromRGB(10,10,13),  bg1  = Color3.fromRGB(15,15,19),
    bg2  = Color3.fromRGB(21,21,26),  bg3  = Color3.fromRGB(30,30,36),
    bg4  = Color3.fromRGB(42,42,50),
    line = Color3.fromRGB(48,48,56),  bdr  = Color3.fromRGB(78,78,90),
    txt  = Color3.fromRGB(238,239,244), txt2 = Color3.fromRGB(170,172,182),
    txt3 = Color3.fromRGB(98,100,110),
    acc      = Color3.fromRGB(212,215,224),
    accDim   = Color3.fromRGB(158,161,172),
    accHov   = Color3.fromRGB(238,240,246),
    ok    = Color3.fromRGB(74,200,118), err = Color3.fromRGB(220,84,84),
    amber = Color3.fromRGB(236,186,72),
    input = Color3.fromRGB(18,18,23),
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

local alive = true
local maid = {}
local function track(conn) table.insert(maid, conn) return conn end

local function attachDrag(handle, target)
    local d, ds, sp = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            d = true; ds = i.Position; sp = target.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then d = false end end)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(i)
        if not d then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local dd = i.Position - ds
            target.Position = UDim2.new(sp.X.Scale, sp.X.Offset+dd.X, sp.Y.Scale, sp.Y.Offset+dd.Y)
        end
    end))
end

local SG = mk("ScreenGui"); SG.Name = "CodeWatcher"
SG.ResetOnSpawn = false; SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 201; SG.IgnoreGuiInset = true; SG.Parent = PG

SG.Destroying:Connect(function()
    alive = false
    for _, c in ipairs(maid) do pcall(function() c:Disconnect() end) end
    table.clear(maid)
end)

local PW, PH, HEAD_H, COLLAPSE_H = 300, 360, 42, 42

local Main = mk("Frame", SG); Main.Name = "Main"
Main.Size = UDim2.new(0, PW, 0, PH)
Main.Position = UDim2.new(0, 28, 0.5, -PH/2)
Main.BackgroundColor3 = K.bg
Main.BackgroundTransparency = 0.12
Main.BorderSizePixel = 0; Main.ClipsDescendants = true; Main.ZIndex = 10
corner(14, Main)
stroke(Main, K.bdr, 1.4, 0.25)

local Head = mk("Frame", Main)
Head.Size = UDim2.new(1, 0, 0, HEAD_H); Head.BackgroundColor3 = K.bg1
Head.BackgroundTransparency = 0.08; Head.BorderSizePixel = 0; Head.ZIndex = 11
corner(14, Head)
local headMask = mk("Frame", Head); headMask.Size = UDim2.new(1,0,0,12)
headMask.Position = UDim2.new(0,0,1,-12); headMask.BackgroundColor3 = K.bg1
headMask.BackgroundTransparency = 0.08; headMask.BorderSizePixel = 0; headMask.ZIndex = 11

local mark = mk("Frame", Head)
mark.Size = UDim2.new(0, 10, 0, 10); mark.AnchorPoint = Vector2.new(0, 0.5)
mark.Position = UDim2.new(0, 14, 0.5, 0); mark.BackgroundColor3 = K.txt3
mark.BorderSizePixel = 0; mark.ZIndex = 12
corner(5, mark)

local title = label("CODE WATCHER", 13, F.black, K.txt, nil, Head)
title.Size = UDim2.new(1, -100, 1, 0); title.Position = UDim2.new(0, 32, 0, 0); title.ZIndex = 12

local function headBtn(symbol, xFromRight, sz)
    local b = mk("TextButton", Head)
    b.Size = UDim2.new(0, 22, 0, 22); b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, xFromRight, 0.5, 0); b.BackgroundColor3 = K.bg3
    b.Text = symbol; b.TextColor3 = K.txt2; b.Font = F.bold; b.TextSize = sz or 12
    b.BorderSizePixel = 0; b.AutoButtonColor = false; b.ZIndex = 13
    corner(7, b); local st = stroke(b, K.bdr, 1, 0)
    b.MouseEnter:Connect(function() tw(b, 0.1, {BackgroundColor3 = K.bg4, TextColor3 = K.accHov}); tw(st, 0.1, {Color = K.acc}) end)
    b.MouseLeave:Connect(function() tw(b, 0.1, {BackgroundColor3 = K.bg3, TextColor3 = K.txt2}); tw(st, 0.1, {Color = K.bdr}) end)
    return b
end

local MinBtn = headBtn("–", -38, 14)
local CloseBtn = headBtn("X", -10, 11)
CloseBtn.MouseEnter:Connect(function() tw(CloseBtn, 0.1, {BackgroundColor3 = K.err, TextColor3 = K.txt}) end)
CloseBtn.MouseLeave:Connect(function() tw(CloseBtn, 0.1, {BackgroundColor3 = K.bg3, TextColor3 = K.txt2}) end)

local collapsed = false
MinBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    MinBtn.Text = collapsed and "+" or "–"
    tw(Main, 0.26, {Size = UDim2.new(0, PW, 0, collapsed and COLLAPSE_H or PH)}, Enum.EasingStyle.Quint)
end)
CloseBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

attachDrag(Head, Main)

local SearchCard = mk("Frame", Main)
SearchCard.Size = UDim2.new(1, -24, 0, 32); SearchCard.Position = UDim2.new(0, 12, 0, HEAD_H + 8)
SearchCard.BackgroundColor3 = K.bg2; SearchCard.BackgroundTransparency = 0.08
SearchCard.BorderSizePixel = 0; SearchCard.ZIndex = 12
corner(8, SearchCard); local searchStroke = stroke(SearchCard, K.line, 1, 0.3)

local SearchBox = mk("TextBox", SearchCard)
SearchBox.Size = UDim2.new(1, -18, 1, 0); SearchBox.Position = UDim2.new(0, 9, 0, 0)
SearchBox.BackgroundTransparency = 1; SearchBox.PlaceholderText = "Search codes"
SearchBox.PlaceholderColor3 = K.txt3; SearchBox.Text = ""; SearchBox.TextColor3 = K.txt
SearchBox.Font = F.med; SearchBox.TextSize = 12; SearchBox.ClearTextOnFocus = false
SearchBox.TextXAlignment = Enum.TextXAlignment.Left; SearchBox.ZIndex = 13
SearchBox.Focused:Connect(function() tw(searchStroke, 0.12, {Color = K.acc, Transparency = 0.05}) end)
SearchBox.FocusLost:Connect(function() tw(searchStroke, 0.12, {Color = K.line, Transparency = 0.3}) end)

local currentFilter = "ALL"
local applyFilter
local TabBar = mk("Frame", Main)
TabBar.Size = UDim2.new(1, -24, 0, 26); TabBar.Position = UDim2.new(0, 12, 0, HEAD_H + 46)
TabBar.BackgroundColor3 = K.bg2; TabBar.BackgroundTransparency = 0.08
TabBar.BorderSizePixel = 0; TabBar.ZIndex = 12
corner(7, TabBar)
local tpad = mk("UIPadding", TabBar); tpad.PaddingTop=UDim.new(0,3); tpad.PaddingBottom=UDim.new(0,3); tpad.PaddingLeft=UDim.new(0,3); tpad.PaddingRight=UDim.new(0,3)
local tlay = mk("UIListLayout", TabBar); tlay.FillDirection=Enum.FillDirection.Horizontal; tlay.SortOrder=Enum.SortOrder.LayoutOrder

local tabButtons = {}
local TAB_DEFS = {{"ALL","All"},{"NEW","New"},{"REDEEMED","Redeemed"}}
local function makeTab(name, lbl, order, frac)
    local b = mk("TextButton", TabBar)
    b.Size = UDim2.new(frac, -3, 1, 0); b.BackgroundColor3 = K.acc; b.BackgroundTransparency = 1
    b.Text = lbl; b.TextColor3 = K.txt2; b.Font = F.bold; b.TextSize = 11
    b.LayoutOrder = order; b.AutoButtonColor = false; b.ZIndex = 13
    corner(5, b); tabButtons[name] = b
    b.MouseButton1Click:Connect(function()
        currentFilter = name
        for n, btn in pairs(tabButtons) do
            local on = n == name
            tw(btn, 0.14, {BackgroundTransparency = on and 0 or 1, TextColor3 = on and Color3.fromRGB(18,18,22) or K.txt2})
        end
        applyFilter()
    end)
    return b
end
for i, def in ipairs(TAB_DEFS) do makeTab(def[1], def[2], i, 1/#TAB_DEFS) end
tabButtons.ALL.BackgroundTransparency = 0
tabButtons.ALL.TextColor3 = Color3.fromRGB(18,18,22)

local CountLabel = label("0 codes", 9, F.bold, K.txt3, nil, Main)
CountLabel.Size = UDim2.new(0.5, 0, 0, 14); CountLabel.Position = UDim2.new(0, 14, 0, HEAD_H + 78); CountLabel.ZIndex = 12

local CopyAll = mk("TextButton", Main)
CopyAll.Size = UDim2.new(0, 80, 0, 14); CopyAll.AnchorPoint = Vector2.new(1, 0)
CopyAll.Position = UDim2.new(1, -14, 0, HEAD_H + 78); CopyAll.BackgroundTransparency = 1
CopyAll.Text = "COPY ALL"; CopyAll.TextColor3 = K.txt3; CopyAll.Font = F.bold; CopyAll.TextSize = 9
CopyAll.TextXAlignment = Enum.TextXAlignment.Right; CopyAll.AutoButtonColor = false; CopyAll.ZIndex = 12
CopyAll.MouseEnter:Connect(function() if CopyAll.Text == "COPY ALL" then tw(CopyAll, 0.1, {TextColor3 = K.accHov}) end end)
CopyAll.MouseLeave:Connect(function() if CopyAll.Text == "COPY ALL" then tw(CopyAll, 0.1, {TextColor3 = K.txt3}) end end)

local Scroll = mk("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -16, 1, -(HEAD_H + 100)); Scroll.Position = UDim2.new(0, 8, 0, HEAD_H + 96)
Scroll.BackgroundTransparency = 1; Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3; Scroll.ScrollBarImageColor3 = K.accDim; Scroll.ScrollBarImageTransparency = 0.3
Scroll.CanvasSize = UDim2.new(0,0,0,0); Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ScrollingDirection = Enum.ScrollingDirection.Y; Scroll.ZIndex = 11
local slay = mk("UIListLayout", Scroll); slay.SortOrder=Enum.SortOrder.LayoutOrder; slay.Padding=UDim.new(0,6)
local spad = mk("UIPadding", Scroll); spad.PaddingTop=UDim.new(0,2); spad.PaddingBottom=UDim.new(0,8); spad.PaddingRight=UDim.new(0,6)

local Empty = label("waiting for codes…", 10, F.med, K.txt3, Enum.TextXAlignment.Center, Scroll)
Empty.Size = UDim2.new(1, 0, 0, 40); Empty.LayoutOrder = 999; Empty.ZIndex = 12

-- ===== REDEEM POPUP =====
local Popup = mk("Frame", SG)
Popup.AnchorPoint = Vector2.new(0.5, 0)
Popup.Position = UDim2.new(0.5, 0, 0, -70)
Popup.Size = UDim2.new(0, 420, 0, 52)
Popup.BackgroundColor3 = K.bg1
Popup.BackgroundTransparency = 1
Popup.BorderSizePixel = 0
Popup.Visible = false
Popup.ZIndex = 50
corner(12, Popup)
local popupStroke = stroke(Popup, K.ok, 1.6, 1)
local PopupLbl = label("", 16, F.black, K.txt, Enum.TextXAlignment.Center, Popup)
PopupLbl.Size = UDim2.new(1, -20, 1, 0); PopupLbl.Position = UDim2.new(0, 10, 0, 0)
PopupLbl.TextWrapped = true; PopupLbl.TextTransparency = 1; PopupLbl.ZIndex = 51

local popupToken = 0
local function showPopup(text)
    popupToken += 1
    local my = popupToken
    PopupLbl.Text = text
    Popup.Visible = true
    Popup.BackgroundTransparency = 1
    PopupLbl.TextTransparency = 1
    popupStroke.Transparency = 1
    Popup.Position = UDim2.new(0.5, 0, 0, -70)
    tw(Popup, 0.32, {Position = UDim2.new(0.5, 0, 0, 26), BackgroundTransparency = 0.05}, Enum.EasingStyle.Back)
    tw(PopupLbl, 0.32, {TextTransparency = 0})
    tw(popupStroke, 0.32, {Transparency = 0.2})
    task.delay(3, function()
        if popupToken ~= my then return end
        tw(Popup, 0.3, {Position = UDim2.new(0.5, 0, 0, -70), BackgroundTransparency = 1})
        tw(PopupLbl, 0.3, {TextTransparency = 1})
        tw(popupStroke, 0.3, {Transparency = 1})
        task.delay(0.3, function() if popupToken == my then Popup.Visible = false end end)
    end)
end

local order = 0
local codes = {}
local scanActive = false

local function fmtTime(sec)
    if sec <= 0 then return "Expired" end
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

function applyFilter()
    local q = SearchBox.Text:lower()
    local shown = 0
    for _, data in pairs(codes) do
        local typeOk
        if currentFilter == "ALL" then
            typeOk = true
        elseif currentFilter == "NEW" then
            typeOk = data.isNew == true
        elseif currentFilter == "REDEEMED" then
            typeOk = data.redeemed == true
        end
        local searchOk = q == "" or data.name:lower():find(q, 1, true) ~= nil
        local vis = typeOk and searchOk
        data.frame.Visible = vis
        if vis then shown += 1 end
    end
    Empty.Visible = shown == 0
    if next(codes) == nil then Empty.Text = "waiting for codes…"
    elseif shown == 0 and currentFilter == "NEW" then Empty.Text = "no new codes yet"
    elseif shown == 0 and currentFilter == "REDEEMED" then Empty.Text = "no codes redeemed yet"
    else Empty.Text = "no matches" end
end
SearchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

local function updateCount()
    local n = 0
    for _ in pairs(codes) do n += 1 end
    CountLabel.Text = n .. (n == 1 and " code" or " codes")
end

local function addCodeEntry(attr, value, codeType)
    if codes[attr] then return end
    order += 1
    local codeName = attr:gsub("StockEvent_Code_", ""):gsub("StockTimestamp_Code_", "")
    local isStock = codeType == "StockEvent"
    local isNew = scanActive

    local function isAvailable()
        if isStock then return true end
        local v = codes[attr] and codes[attr].value or value
        return (v - DateTime.now().UnixTimestamp) > 0
    end
    local avail = isAvailable()

    local Card = mk("Frame", Scroll)
    Card.Size = UDim2.new(1, 0, 0, 46); Card.BackgroundColor3 = K.bg3
    Card.BackgroundTransparency = 0.05; Card.BorderSizePixel = 0; Card.LayoutOrder = -order; Card.ZIndex = 12
    corner(8, Card); local cs = stroke(Card, isNew and K.acc or K.line, 1, isNew and 0.2 or 0.4)

    local Dot = mk("Frame", Card)
    Dot.Size = UDim2.new(0, 7, 0, 7); Dot.AnchorPoint = Vector2.new(0, 0.5)
    Dot.Position = UDim2.new(0, 11, 0, 14); Dot.BackgroundColor3 = avail and K.acc or K.txt3
    Dot.BorderSizePixel = 0; Dot.ZIndex = 13; corner(50, Dot)

    local Code = label(codeName, 13, F.black, avail and K.txt or K.txt3, nil, Card)
    Code.Size = UDim2.new(1, -30, 0, 15); Code.Position = UDim2.new(0, 24, 0, 6)
    Code.TextTruncate = Enum.TextTruncate.AtEnd; Code.ZIndex = 13

    local Hint = label("", 9, F.med, K.txt2, nil, Card)
    Hint.Size = UDim2.new(1, -30, 0, 12); Hint.Position = UDim2.new(0, 24, 0, 24)
    Hint.TextTruncate = Enum.TextTruncate.AtEnd; Hint.ZIndex = 13

    local function baseHint()
        local v = codes[attr] and codes[attr].value or value
        if isStock then return tostring(v) .. " in stock"
        else
            local left = v - DateTime.now().UnixTimestamp
            if left <= 0 then return "Expired" end
            return "Expires in " .. fmtTime(left)
        end
    end
    Hint.Text = baseHint()

    local entry = {
        frame = Card, name = codeName, type = codeType, value = value,
        hint = Hint, baseHint = baseHint, dot = Dot, code = Code, cardStroke = cs,
        isAvailable = isAvailable, expired = false, isNew = isNew, busy = false, redeemed = false, reward = nil,
    }
    codes[attr] = entry

    local function performRedeem()
        if entry.busy or entry.redeemed then return end
        entry.busy = true
        Hint.Text = "Redeeming…"; Hint.TextColor3 = K.amber
        task.spawn(function()
            local ok, result
            for attempt = 1, MAX_TRIES do
                local hard
                ok, result, hard = redeem(codeName)
                if ok or hard then break end          -- success, or a definitive reject
                if attempt < MAX_TRIES then task.wait(0.3 * attempt) end  -- transient: back off & retry
            end
            if not Hint.Parent then return end
            if ok then
                local reward = describeReward(result)
                entry.redeemed = true; entry.reward = reward; entry.busy = false
                Hint.Text = reward and ("Got: " .. reward) or "Redeemed"
                Hint.TextColor3 = K.ok
                tw(Dot, 0.2, {BackgroundColor3 = K.ok})
                tw(cs, 0.2, {Color = K.ok, Transparency = 0.2})
                applyFilter()
                showPopup(("REDEEMED %s PUSSY BITCH"):format(string.upper(reward or codeName)))
            else
                entry.busy = false
                Hint.Text = "invalid / cooldown"; Hint.TextColor3 = K.err
                task.delay(3, function()
                    if not Hint.Parent or entry.redeemed then return end
                    Hint.TextColor3 = K.txt2; Hint.Text = baseHint()
                end)
            end
        end)
    end
    entry.performRedeem = performRedeem

    -- Auto-redeem if: a freshly-dropped code, OR (configured) a code that is
    -- already live the moment we join.
    local function wantRedeem()
        if entry.busy or entry.redeemed then return false end
        if isNew then return true end
        if REDEEM_EXISTING and avail then return true end
        return false
    end

    updateCount(); applyFilter()
    if wantRedeem() then performRedeem() end
end

local function removeCodeEntry(attr)
    local d = codes[attr]
    if d then
        tw(d.frame, 0.2, {BackgroundTransparency = 1})
        task.delay(0.2, function() if d.frame then d.frame:Destroy() end end)
        codes[attr] = nil; updateCount(); applyFilter()
    end
end

task.spawn(function()
    while alive and Main.Parent do
        for _, d in pairs(codes) do
            if d.type == "Timestamp" then
                if not d.isAvailable() and not d.expired then
                    d.expired = true
                    if not d.redeemed then
                        tw(d.dot, 0.3, {BackgroundColor3 = K.txt3})
                        tw(d.code, 0.3, {TextColor3 = K.txt3})
                    end
                end
                if not d.busy and not d.redeemed then
                    d.hint.Text = d.baseHint(); d.hint.TextColor3 = K.txt2
                end
            end
        end
        task.wait(1)
    end
end)

CopyAll.MouseButton1Click:Connect(function()
    local list = {}
    for _, d in pairs(codes) do if d.frame.Visible then table.insert(list, d.name) end end
    if #list > 0 then
        copyText(table.concat(list, "\n"))
        CopyAll.Text = "COPIED"; CopyAll.TextColor3 = K.ok
        task.delay(1.4, function() if CopyAll.Parent then CopyAll.Text = "COPY ALL"; CopyAll.TextColor3 = K.txt3 end end)
    end
end)

local function ingest(attr, value)
    if value == nil then return end
    if attr:find("StockEvent_Code_") then
        if value == 0 then removeCodeEntry(attr) return end
        if codes[attr] then
            codes[attr].value = value
            if not codes[attr].busy and not codes[attr].redeemed then codes[attr].hint.Text = codes[attr].baseHint() end
        else addCodeEntry(attr, value, "StockEvent") end
    elseif attr:find("StockTimestamp_Code_") then
        if codes[attr] then codes[attr].value = value
        else addCodeEntry(attr, value, "Timestamp") end
    end
end

-- 1) Snapshot whatever already exists. scanActive is still false, so these are
--    treated as "existing" (redeemed only if REDEEM_EXISTING and live).
for k, v in pairs(ReplicatedStorage:GetAttributes()) do ingest(k, v) end

-- 2) From this point on, ANY new attribute is a freshly-dropped code. No 5s
--    blind window — we want to fire the instant it lands.
scanActive = true

-- 3) Listen with zero added delay.
track(ReplicatedStorage.AttributeChanged:Connect(function(attr)
    ingest(attr, ReplicatedStorage:GetAttribute(attr))
end))

-- 4) Safety net: AttributeChanged can occasionally be missed, so poll for any
--    key we haven't seen. Anything found here counts as new -> instant redeem.
task.spawn(function()
    while alive and Main.Parent do
        for k, v in pairs(ReplicatedStorage:GetAttributes()) do
            if not codes[k] then ingest(k, v) end
        end
        task.wait(1.5)
    end
end)

if ensureRedeemRemote() then
    mark.BackgroundColor3 = K.ok
    print("[CodeWatcher] Redeem locked ->", RedeemRemote.Name)
else
    warn("[CodeWatcher] redeem remote not found — RF/RequestRedemption / RE/StockEventService/Redeem missing in Net.")
    task.spawn(function()
        while alive and not ensureRedeemRemote() do task.wait(0.5) end
        if RedeemRemote then mark.BackgroundColor3 = K.ok; print("[CodeWatcher] Redeem resolved late:", RedeemRemote.Name) end
    end)
end
