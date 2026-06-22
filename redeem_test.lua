-- ============================================================
-- PHI REDEEM TESTER
-- Type a REAL valid code, then click a remote to redeem THROUGH it and
-- see the actual result. This proves which remote really works (not just
-- "fires"). RemoteFunctions show the server's return; RemoteEvents fire
-- and you watch the game's popup.
-- ============================================================

local RS  = game:GetService("ReplicatedStorage")
local Net = RS:WaitForChild("Packages"):WaitForChild("Net")
local PG  = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local HTTP = game:GetService("HttpService")

-- gather candidate redeem remotes
local cands = {}
local function add(r) if r then for _, e in ipairs(cands) do if e == r then return end end table.insert(cands, r) end end
add(Net:FindFirstChild("RE/StockEventService/Redeem"))   -- likely the EVENT/announced-code redeem
add(Net:FindFirstChild("RF/RequestRedemption"))          -- the manual Codes-menu redeem
if typeof(_G.PhiRedeemRemote) == "Instance" then add(_G.PhiRedeemRemote) end   -- captured one
if #cands == 0 then warn("[RedeemTest] no candidate remotes found"); return end

local function tryRedeem(remote, code)
    if remote:IsA("RemoteFunction") then
        local ok, res = pcall(function() return remote:InvokeServer(code) end)
        if not ok then return "ERROR: " .. tostring(res) end
        if type(res) == "table" then return "returned " .. HTTP:JSONEncode(res) end
        return "returned " .. tostring(res)
    else
        local ok, err = pcall(function() remote:FireServer(code) end)
        return ok and "fired — watch the popup" or ("ERROR: " .. tostring(err))
    end
end

-- ── UI ───────────────────────────────────────────────────────────
local old = PG:FindFirstChild("PhiRedeemTest"); if old then old:Destroy() end
local SG = Instance.new("ScreenGui"); SG.Name = "PhiRedeemTest"; SG.ResetOnSpawn = false; SG.Parent = PG
local function corner(r,p) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r) end

local W = Instance.new("Frame", SG)
W.Size = UDim2.new(0, 320, 0, 104 + #cands*34); W.Position = UDim2.new(0.5,-160,0.5,-110)
W.BackgroundColor3 = Color3.fromRGB(14,14,18); W.BorderSizePixel = 0; corner(10, W)
Instance.new("UIStroke", W).Color = Color3.fromRGB(80,80,92)

local title = Instance.new("TextLabel", W)
title.Size = UDim2.new(1,-40,0,28); title.Position = UDim2.new(0,12,0,4); title.BackgroundTransparency = 1
title.Text = "REDEEM TESTER"; title.TextColor3 = Color3.fromRGB(235,236,242)
title.Font = Enum.Font.GothamBold; title.TextSize = 13; title.TextXAlignment = Enum.TextXAlignment.Left
local close = Instance.new("TextButton", W)
close.Size = UDim2.new(0,22,0,22); close.Position = UDim2.new(1,-28,0,6); close.Text = "X"
close.BackgroundColor3 = Color3.fromRGB(30,30,36); close.TextColor3 = Color3.fromRGB(200,200,210)
close.Font = Enum.Font.GothamBold; close.TextSize = 11; close.BorderSizePixel = 0; corner(6, close)
close.MouseButton1Click:Connect(function() SG:Destroy() end)

local box = Instance.new("TextBox", W)
box.Size = UDim2.new(1,-24,0,30); box.Position = UDim2.new(0,12,0,34)
box.BackgroundColor3 = Color3.fromRGB(20,20,26); box.BorderSizePixel = 0
box.PlaceholderText = "type a REAL code…"; box.PlaceholderColor3 = Color3.fromRGB(110,112,122)
box.Text = ""; box.TextColor3 = Color3.fromRGB(235,236,242); box.ClearTextOnFocus = false
box.Font = Enum.Font.GothamBold; box.TextSize = 13; box.TextXAlignment = Enum.TextXAlignment.Left
corner(6, box); local bp = Instance.new("UIPadding", box); bp.PaddingLeft = UDim.new(0,8); bp.PaddingRight = UDim.new(0,8)

local result = Instance.new("TextLabel", W)
result.Size = UDim2.new(1,-24,0,22); result.Position = UDim2.new(0,12,1,-26); result.BackgroundTransparency = 1
result.Text = "type a code, then click a remote"; result.TextColor3 = Color3.fromRGB(170,172,182)
result.Font = Enum.Font.Gotham; result.TextSize = 11; result.TextXAlignment = Enum.TextXAlignment.Left
result.TextTruncate = Enum.TextTruncate.AtEnd

for i, r in ipairs(cands) do
    local b = Instance.new("TextButton", W)
    b.Size = UDim2.new(1,-24,0,28); b.Position = UDim2.new(0,12,0,70+(i-1)*34)
    b.BackgroundColor3 = Color3.fromRGB(30,30,36); b.BorderSizePixel = 0
    b.Text = (r:IsA("RemoteFunction") and "RF  " or "RE  ") .. r.Name
    b.TextColor3 = Color3.fromRGB(235,236,242); b.Font = Enum.Font.GothamMedium; b.TextSize = 10
    b.TextXAlignment = Enum.TextXAlignment.Left; b.TextTruncate = Enum.TextTruncate.AtEnd; corner(6, b)
    local p2 = Instance.new("UIPadding", b); p2.PaddingLeft = UDim.new(0,8); p2.PaddingRight = UDim.new(0,8)
    b.MouseButton1Click:Connect(function()
        local code = (box.Text or ""):gsub("^%s+",""):gsub("%s+$","")
        if code == "" then result.Text = "enter a code first"; return end
        result.Text = "…"
        task.spawn(function()
            local res = tryRedeem(r, code)
            result.Text = res
            print("[RedeemTest] " .. r.Name .. " -> " .. res)
        end)
    end)
end

print("[RedeemTest] ready —", #cands, "candidate remote(s). Type a REAL code and click each.")
