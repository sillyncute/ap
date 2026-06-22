-- ============================================================
-- PHI TEST SENDER  (standalone)
-- A tiny window to fire FAKE announcements through the real notify
-- remote (real popup + bloop). Load Phi first so it catches them into
-- the feed / listen flow. Auto-resolves the remote (no hash).
--   SEND       -> fires whatever you typed
--   TEST CODE  -> fires a random TESTCODE####
-- firesignal is LOCAL — nothing reaches the server.
-- ============================================================

local Players = game:GetService("Players")
local RS  = game:GetService("ReplicatedStorage")
local Net = RS:WaitForChild("Packages"):WaitForChild("Net")
local PG  = Players.LocalPlayer:WaitForChild("PlayerGui")

if typeof(firesignal) ~= "function" then
    warn("[TestSender] executor has no 'firesignal' — cannot fake announcements.")
    return
end

-- resolve the notify remote: Phi's _G, else via NotificationController
local function resolveRemote()
    if _G.PhiNotifyRemote then return _G.PhiNotifyRemote end
    local getinfo = debug and (debug.getinfo or debug.info)
    if getgc and getinfo then
        local getups, getconsts = debug.getupvalues, debug.getconstants
        local function pick(l) for _,v in pairs(l) do if typeof(v)=="Instance" and v:IsA("RemoteEvent") and v.Name:match("^RE/%x+$") then return v end end end
        if getconnections then
            for _, d in ipairs(Net:GetDescendants()) do
                if d:IsA("RemoteEvent") then
                    local ok, cs = pcall(getconnections, d.OnClientEvent)
                    if ok then for _, c in ipairs(cs) do
                        local f, fn = pcall(function() return c.Function end)
                        if f and type(fn)=="function" then
                            local i, info = pcall(getinfo, fn)
                            if i and tostring(info.short_src or info.source or ""):find("NotificationController",1,true) then return d end
                        end
                    end end
                end
            end
        end
    end
end

local remote = resolveRemote()
if not remote then
    warn("[TestSender] notify remote not found — load Phi first, then run this.")
    return
end
print("[TestSender] using remote:", remote.Name)

local function fire(txt)
    txt = (txt or ""):gsub("^%s+",""):gsub("%s+$","")
    if txt == "" then return end
    firesignal(remote.OnClientEvent, txt, 5.5, "Sounds.Sfx.Blop", "Top", 2678001507)
end

-- ── minimal UI ───────────────────────────────────────────────────
local old = PG:FindFirstChild("PhiTestSender"); if old then old:Destroy() end
local SG = Instance.new("ScreenGui"); SG.Name = "PhiTestSender"
SG.ResetOnSpawn = false; SG.DisplayOrder = 205; SG.Parent = PG

local function corner(r,p) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r) end
local function stroke(p) local s=Instance.new("UIStroke",p); s.Color=Color3.fromRGB(78,78,90); s.Transparency=0.25; return s end

local W = Instance.new("Frame", SG)
W.Size = UDim2.new(0, 280, 0, 138); W.Position = UDim2.new(0.5, -140, 0.5, -69)
W.BackgroundColor3 = Color3.fromRGB(12,12,15); W.BackgroundTransparency = 0.06
W.BorderSizePixel = 0; corner(12, W); stroke(W)

local head = Instance.new("Frame", W)
head.Size = UDim2.new(1,0,0,30); head.BackgroundColor3 = Color3.fromRGB(18,18,22)
head.BorderSizePixel = 0; corner(12, head)
local title = Instance.new("TextLabel", head)
title.BackgroundTransparency = 1; title.Size = UDim2.new(1,-40,1,0); title.Position = UDim2.new(0,12,0,0)
title.Text = "TEST SENDER"; title.TextColor3 = Color3.fromRGB(238,239,244)
title.Font = Enum.Font.GothamBold; title.TextSize = 12; title.TextXAlignment = Enum.TextXAlignment.Left
local close = Instance.new("TextButton", head)
close.Size = UDim2.new(0,20,0,20); close.Position = UDim2.new(1,-26,0.5,-10)
close.BackgroundColor3 = Color3.fromRGB(30,30,36); close.Text = "X"
close.TextColor3 = Color3.fromRGB(200,200,210); close.Font = Enum.Font.GothamBold; close.TextSize = 10
close.BorderSizePixel = 0; corner(8, close)
close.MouseButton1Click:Connect(function() SG:Destroy() end)

-- drag
do
    local drag, ds, sp
    head.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=true; ds=i.Position; sp=W.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end) end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds; W.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end
    end)
end

local box = Instance.new("TextBox", W)
box.Size = UDim2.new(1,-24,0,32); box.Position = UDim2.new(0,12,0,42)
box.BackgroundColor3 = Color3.fromRGB(18,18,23); box.BorderSizePixel = 0
box.PlaceholderText = "type a word or message…"; box.PlaceholderColor3 = Color3.fromRGB(110,112,122)
box.Text = ""; box.TextColor3 = Color3.fromRGB(238,239,244); box.ClearTextOnFocus = false
box.Font = Enum.Font.GothamBold; box.TextSize = 13; box.TextXAlignment = Enum.TextXAlignment.Left
corner(6, box); stroke(box)
local pad = Instance.new("UIPadding", box); pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)

local send = Instance.new("TextButton", W)
send.Size = UDim2.new(0,150,0,30); send.Position = UDim2.new(0,12,1,-38)
send.BackgroundColor3 = Color3.fromRGB(212,215,224); send.Text = "SEND"
send.TextColor3 = Color3.fromRGB(18,18,22); send.Font = Enum.Font.GothamBold; send.TextSize = 12
send.BorderSizePixel = 0; send.AutoButtonColor = true; corner(6, send)

local tc = Instance.new("TextButton", W)
tc.Size = UDim2.new(0,94,0,30); tc.Position = UDim2.new(0,170,1,-38)
tc.BackgroundColor3 = Color3.fromRGB(30,30,36); tc.Text = "TEST CODE"
tc.TextColor3 = Color3.fromRGB(238,239,244); tc.Font = Enum.Font.GothamBold; tc.TextSize = 10
tc.BorderSizePixel = 0; tc.AutoButtonColor = true; corner(6, tc); stroke(tc)

send.MouseButton1Click:Connect(function() fire(box.Text); box.Text=""; box:CaptureFocus() end)
box.FocusLost:Connect(function(enter) if enter then fire(box.Text); box.Text=""; box:CaptureFocus() end end)
tc.MouseButton1Click:Connect(function() fire("TESTCODE" .. tostring(math.random(1000,9999))) end)

print("[TestSender] ready — load Phi to catch what you send.")
