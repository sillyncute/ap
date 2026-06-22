-- ============================================================
-- PHI REDEEM PROBE
-- Fires a FAKE code through each candidate redeem remote and watches for
-- the server's "Invalid code" / "please wait" response. The remote that
-- produces that response IS the real redeem remote.
--
-- NOTE: this DOES reach the server (a fake redeem). It only tries a few
-- curated candidates, spaces them out, and STOPS at the first that
-- responds — so it won't spam. Saves the result to _G.PhiRedeemRemote.
-- ============================================================

local RS  = game:GetService("ReplicatedStorage")
local Net = RS:WaitForChild("Packages"):WaitForChild("Net")
local PG  = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local HTTP = game:GetService("HttpService")

-- candidates: the two you found + captured + any readable redeem-named remote
local cands, seen = {}, {}
local function add(r)
    if r and not seen[r] and (r:IsA("RemoteFunction") or r:IsA("RemoteEvent")) then
        seen[r] = true; table.insert(cands, r)
    end
end
add(Net:FindFirstChild("RE/StockEventService/Redeem"))   -- likely the announced-code redeem
add(Net:FindFirstChild("RF/RequestRedemption"))          -- the manual Codes-menu redeem
if typeof(_G.PhiRedeemRemote) == "Instance" then add(_G.PhiRedeemRemote) end
for _, d in ipairs(Net:GetChildren()) do
    local n = d.Name:lower()
    if n:find("redeem") or n:find("redemption") then add(d) end
end
if #cands == 0 then warn("[Probe] no candidate redeem remotes found"); return end

local CODE = "ZZPROBE" .. tostring(math.random(1000, 9999))   -- definitely invalid

-- look for a server response popup (invalid / wait / already)
local function responseText()
    for _, d in ipairs(PG:GetDescendants()) do
        if d:IsA("TextLabel") then
            local t = (d.Text or ""):lower()
            if t:find("invalid") or t:find("wait before") or t:find("already") or t:find("expired") then
                return d.Text
            end
        end
    end
end

print("[Probe] testing", #cands, "candidate(s) with fake code:", CODE)
local found
for _, r in ipairs(cands) do
    print("[Probe] trying:", r.Name, "(" .. r.ClassName .. ")")
    if r:IsA("RemoteFunction") then
        local ok, res = pcall(function() return r:InvokeServer(CODE) end)
        if ok and res ~= nil then
            found = r
            print("[Probe] ✅ " .. r.Name .. " RETURNED: " ..
                  (typeof(res) == "table" and HTTP:JSONEncode(res) or tostring(res)))
            break
        end
    else
        pcall(function() r:FireServer(CODE) end)
        task.wait(0.6)
        local popup = responseText()
        if popup then
            found = r
            print("[Probe] ✅ " .. r.Name .. " POPUP: " .. popup)
            break
        end
    end
    task.wait(0.9)   -- spacing to ease the redeem cooldown
end

print("==========================================")
if found then
    _G.PhiRedeemRemote = found
    print("[Probe] REDEEM REMOTE =", found.Name, "(" .. found.ClassName .. ")")
    print("[Probe] saved to _G.PhiRedeemRemote — Phi will use it.")
else
    warn("[Probe] no candidate produced an invalid/wait response.")
    warn("[Probe] Tell me and I'll widen the candidate list.")
end
print("==========================================")
