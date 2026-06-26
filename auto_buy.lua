local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

local Player = Players.LocalPlayer
local PG  = Player:WaitForChild("PlayerGui")

for _, n in ipairs({"AutoBuy"}) do
    local old = PG:FindFirstChild(n); if old then old:Destroy() end
end

-- ===== CONFIG =====================================================
local RANGE       = 18      -- studs; fire any prompt within this of the player (slider-adjustable)
local RANGE_MIN   = 4
local RANGE_MAX   = 80
local INTERVAL    = 0.08    -- min seconds between firing the SAME prompt
local RESPECT_MAX = true    -- also obey each prompt's own MaxActivationDistance
-- Starting position of the panel (draggable from here):
local ANCHOR_POS  = UDim2.new(0, 28, 0.5, -78)
-- ==================================================================

-- ---- prompt firing -------------------------------------------------
local fireprompt = fireproximityprompt or (firepromptprompt) -- executor global
local function promptWorldPos(prompt)
    local p = prompt.Parent
    if not p then return nil end
    if p:IsA("Attachment") then return p.WorldPosition end
    if p:IsA("BasePart") then return p.Position end
    -- prompt parented to something else; try an ancestor part
    local part = prompt:FindFirstAncestorWhichIsA("BasePart")
    return part and part.Position or nil
end

local function trigger(prompt)
    if fireprompt then
        pcall(fireprompt, prompt)
        return
    end
    -- fallback for executors without fireproximityprompt: zero the hold and
    -- drive the input manually
    pcall(function()
        local saved = prompt.HoldDuration
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        task.defer(function()
            pcall(function() prompt:InputHoldEnd() end)
            prompt.HoldDuration = saved
        end)
    end)
end

-- ---- theme (matches CodeWatcher) ----------------------------------
local function pickFont(getter, fallback)
    local ok, f = pcall(getter)
    if ok and typeof(f) == "EnumItem" then return f end
    return fallback
end
local F = {
    med   = pickFont(function() return Enum.Font.BuilderSansMedium end,    Enum.Font.GothamMedium),
    bold  = pickFont(function() return Enum.Font.BuilderSansBold end,      Enum.Font.GothamBold),
    black = pickFont(function() return Enum.Font.BuilderSansExtraBold end, Enum.Font.GothamBlack),
}
local K = {
    bg   = Color3.fromRGB(10,10,13),  bg1  = Color3.fromRGB(15,15,19),
    bg2  = Color3.fromRGB(21,21,26),  bg3  = Color3.fromRGB(30,30,36),
    line = Color3.fromRGB(48,48,56),  bdr  = Color3.fromRGB(78,78,90),
    txt  = Color3.fromRGB(238,239,244), txt2 = Color3.fromRGB(170,172,182),
    txt3 = Color3.fromRGB(98,100,110),
    acc  = Color3.fromRGB(212,215,224),
    ok   = Color3.fromRGB(74,200,118), err = Color3.fromRGB(220,84,84),
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

-- ---- UI (anchored — fixed position, not draggable) -----------------
local SG = mk("ScreenGui"); SG.Name = "AutoBuy"
SG.ResetOnSpawn = false; SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 202; SG.IgnoreGuiInset = true; SG.Parent = PG

local PW, PH = 220, 150
local Main = mk("Frame", SG); Main.Name = "Main"
Main.Size = UDim2.new(0, PW, 0, PH)
Main.Position = ANCHOR_POS          -- fixed anchor; never changes
Main.BackgroundColor3 = K.bg
Main.BackgroundTransparency = 0.12
Main.BorderSizePixel = 0; Main.ZIndex = 10
corner(14, Main)
stroke(Main, K.bdr, 1.4, 0.25)

local Head = mk("Frame", Main)
Head.Size = UDim2.new(1, 0, 0, 38); Head.BackgroundColor3 = K.bg1
Head.BackgroundTransparency = 0.08; Head.BorderSizePixel = 0; Head.ZIndex = 11
corner(14, Head)
local headMask = mk("Frame", Head); headMask.Size = UDim2.new(1,0,0,12)
headMask.Position = UDim2.new(0,0,1,-12); headMask.BackgroundColor3 = K.bg1
headMask.BackgroundTransparency = 0.08; headMask.BorderSizePixel = 0; headMask.ZIndex = 11

local mark = mk("Frame", Head)
mark.Size = UDim2.new(0, 10, 0, 10); mark.AnchorPoint = Vector2.new(0, 0.5)
mark.Position = UDim2.new(0, 14, 0.5, 0); mark.BackgroundColor3 = K.txt3
mark.BorderSizePixel = 0; mark.ZIndex = 12; corner(5, mark)

local title = label("AUTO BUY", 13, F.black, K.txt, nil, Head)
title.Size = UDim2.new(1, -50, 1, 0); title.Position = UDim2.new(0, 32, 0, 0); title.ZIndex = 12

-- ANCHOR toggle — freezes your character in place (HumanoidRootPart.Anchored)
local anchored = false
local AnchorBtn = mk("TextButton", Head)
AnchorBtn.Size = UDim2.new(0, 22, 0, 22); AnchorBtn.AnchorPoint = Vector2.new(1, 0.5)
AnchorBtn.Position = UDim2.new(1, -10, 0.5, 0); AnchorBtn.BackgroundColor3 = K.bg3
AnchorBtn.Text = "⚓"; AnchorBtn.TextColor3 = K.txt2; AnchorBtn.Font = F.bold; AnchorBtn.TextSize = 12
AnchorBtn.BorderSizePixel = 0; AnchorBtn.AutoButtonColor = false; AnchorBtn.ZIndex = 13
corner(7, AnchorBtn); local anchorStroke = stroke(AnchorBtn, K.bdr, 1, 0)

local StatLbl = label("idle", 9, F.bold, K.txt3, Enum.TextXAlignment.Right, Head)
StatLbl.Size = UDim2.new(0, 70, 1, 0); StatLbl.AnchorPoint = Vector2.new(1, 0)
StatLbl.Position = UDim2.new(1, -40, 0, 0); StatLbl.ZIndex = 12

local function applyAnchorToChar()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Anchored = anchored end
end
local function setAnchored(on)
    anchored = on
    applyAnchorToChar()
    if on then
        tw(AnchorBtn, 0.12, {BackgroundColor3 = K.acc, TextColor3 = Color3.fromRGB(18,18,22)})
        tw(anchorStroke, 0.12, {Color = K.acc})
    else
        tw(AnchorBtn, 0.12, {BackgroundColor3 = K.bg3, TextColor3 = K.txt2})
        tw(anchorStroke, 0.12, {Color = K.bdr})
    end
end
AnchorBtn.MouseButton1Click:Connect(function() setAnchored(not anchored) end)
-- re-apply on respawn so you stay frozen across deaths
Player.CharacterAdded:Connect(function(char)
    if not anchored then return end
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp then hrp.Anchored = true end
end)

-- toggle row
local Toggle = mk("TextButton", Main)
Toggle.Size = UDim2.new(1, -24, 0, 34); Toggle.Position = UDim2.new(0, 12, 0, 48)
Toggle.BackgroundColor3 = K.bg3; Toggle.BackgroundTransparency = 0.05
Toggle.Text = ""; Toggle.AutoButtonColor = false; Toggle.BorderSizePixel = 0; Toggle.ZIndex = 12
corner(9, Toggle); local toggleStroke = stroke(Toggle, K.line, 1, 0.3)

local TogLbl = label("AUTO HOLD  E", 12, F.bold, K.txt2, nil, Toggle)
TogLbl.Size = UDim2.new(1, -56, 1, 0); TogLbl.Position = UDim2.new(0, 12, 0, 0); TogLbl.ZIndex = 13

local Knob = mk("Frame", Toggle)
Knob.Size = UDim2.new(0, 34, 0, 18); Knob.AnchorPoint = Vector2.new(1, 0.5)
Knob.Position = UDim2.new(1, -10, 0.5, 0); Knob.BackgroundColor3 = K.line
Knob.BorderSizePixel = 0; Knob.ZIndex = 13; corner(9, Knob)
local Pip = mk("Frame", Knob)
Pip.Size = UDim2.new(0, 14, 0, 14); Pip.AnchorPoint = Vector2.new(0, 0.5)
Pip.Position = UDim2.new(0, 2, 0.5, 0); Pip.BackgroundColor3 = K.txt2
Pip.BorderSizePixel = 0; Pip.ZIndex = 14; corner(7, Pip)

-- range slider row
local SliderLbl = label("RANGE", 10, F.bold, K.txt2, nil, Main)
SliderLbl.Size = UDim2.new(0.5, 0, 0, 14); SliderLbl.Position = UDim2.new(0, 12, 0, 88); SliderLbl.ZIndex = 12
local SliderVal = label(tostring(RANGE) .. " studs", 10, F.bold, K.acc, Enum.TextXAlignment.Right, Main)
SliderVal.Size = UDim2.new(0.5, -12, 0, 14); SliderVal.AnchorPoint = Vector2.new(1, 0)
SliderVal.Position = UDim2.new(1, -12, 0, 88); SliderVal.ZIndex = 12

local Track = mk("Frame", Main)
Track.Size = UDim2.new(1, -24, 0, 6); Track.Position = UDim2.new(0, 12, 0, 108)
Track.BackgroundColor3 = K.bg3; Track.BorderSizePixel = 0; Track.ZIndex = 12
corner(3, Track); stroke(Track, K.line, 1, 0.4)
local Fill = mk("Frame", Track)
Fill.BackgroundColor3 = K.acc; Fill.BorderSizePixel = 0; Fill.ZIndex = 13; corner(3, Fill)
local Handle = mk("Frame", Track)
Handle.Size = UDim2.new(0, 14, 0, 14); Handle.AnchorPoint = Vector2.new(0.5, 0.5)
Handle.BackgroundColor3 = K.txt; Handle.BorderSizePixel = 0; Handle.ZIndex = 14
corner(7, Handle); stroke(Handle, K.bdr, 1, 0)

local function applySlider(frac)
    frac = math.clamp(frac, 0, 1)
    RANGE = math.floor(RANGE_MIN + (RANGE_MAX - RANGE_MIN) * frac + 0.5)
    SliderVal.Text = RANGE .. " studs"
    Fill.Size = UDim2.new(frac, 0, 1, 0)
    Handle.Position = UDim2.new(frac, 0, 0.5, 0)
end
applySlider((RANGE - RANGE_MIN) / (RANGE_MAX - RANGE_MIN))

local sliding = false
local function frameFromX(x)
    local left = Track.AbsolutePosition.X
    local w = Track.AbsoluteSize.X
    if w <= 0 then return end
    applySlider((x - left) / w)
end
Track.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        sliding = true; frameFromX(i.Position.X)
    end
end)
Handle.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        sliding = true
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        frameFromX(i.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        sliding = false
    end
end)

local Info = label("0 prompts in range", 9, F.med, K.txt3, nil, Main)
Info.Size = UDim2.new(1, -24, 0, 14); Info.Position = UDim2.new(0, 12, 0, 124); Info.ZIndex = 12

-- ---- toggle + loop -------------------------------------------------
local enabled = false
local lastFire = {}        -- prompt -> last os.clock() we fired it
local conn

local function setEnabled(on)
    enabled = on
    if on then
        tw(Knob, 0.16, {BackgroundColor3 = K.ok})
        tw(Pip, 0.16, {Position = UDim2.new(1, -16, 0.5, 0), BackgroundColor3 = Color3.fromRGB(15,20,15)})
        tw(TogLbl, 0.16, {TextColor3 = K.txt})
        tw(toggleStroke, 0.16, {Color = K.ok, Transparency = 0.2})
        tw(mark, 0.16, {BackgroundColor3 = K.ok})
        StatLbl.Text = "ON"; StatLbl.TextColor3 = K.ok
    else
        tw(Knob, 0.16, {BackgroundColor3 = K.line})
        tw(Pip, 0.16, {Position = UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = K.txt2})
        tw(TogLbl, 0.16, {TextColor3 = K.txt2})
        tw(toggleStroke, 0.16, {Color = K.line, Transparency = 0.3})
        tw(mark, 0.16, {BackgroundColor3 = K.txt3})
        StatLbl.Text = "idle"; StatLbl.TextColor3 = K.txt3
        Info.Text = "0 prompts in range"
    end
end

Toggle.MouseButton1Click:Connect(function() setEnabled(not enabled) end)

conn = RunService.Heartbeat:Connect(function()
    if not enabled then return end
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then Info.Text = "no character"; return end
    local origin = hrp.Position
    local now = os.clock()
    local inRange = 0

    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled and d.KeyboardKeyCode == Enum.KeyCode.E then
            local pos = promptWorldPos(d)
            if pos then
                local dist = (pos - origin).Magnitude
                local maxD = RESPECT_MAX and math.min(RANGE, d.MaxActivationDistance) or RANGE
                if dist <= maxD then
                    inRange += 1
                    local last = lastFire[d] or 0
                    if now - last >= INTERVAL then
                        lastFire[d] = now
                        trigger(d)
                    end
                end
            end
        end
    end
    Info.Text = inRange .. (inRange == 1 and " prompt in range" or " prompts in range")
end)

SG.Destroying:Connect(function()
    if conn then conn:Disconnect() end
end)

-- drag the panel by its header (disabled while the anchor toggle is ON)
do
    local dragging, dragStart, startPos = false, nil, nil
    Head.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = Main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

if not fireprompt then
    StatLbl.Text = "no fireprompt"; StatLbl.TextColor3 = K.err
    warn("[AutoBuy] fireproximityprompt not found — using input-hold fallback (may be slower).")
end
print("[AutoBuy] ready. Drag by the header; ⚓ anchors your character. Auto-holds E on E-prompts within", RANGE, "studs.")
