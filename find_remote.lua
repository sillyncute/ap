-- ============================================================
-- PHI REMOTE FINDER
-- Actively locates the CURRENT notify remote WITHOUT waiting for a
-- real announcement. It fires a unique fake announcement through each
-- hash-named RemoteEvent and detects which one makes the game draw a
-- popup (a label containing our unique marker).
--
-- firesignal is LOCAL (client-side) — nothing reaches the server, so
-- this can't cause a server-side kick. Only hash-named (obfuscated)
-- remotes are probed, so readable gameplay remotes are left alone.
--
-- On success it prints the remote name and saves it to
-- _G.PhiNotifyRemote, which Phi's test (notify_test.lua) auto-uses.
-- ============================================================

local Players = game:GetService("Players")
local RS  = game:GetService("ReplicatedStorage")
local Net = RS:WaitForChild("Packages"):WaitForChild("Net")
local PG  = Players.LocalPlayer:WaitForChild("PlayerGui")

if typeof(firesignal) ~= "function" then
    warn("[Find] Your executor has no 'firesignal' — cannot probe. Aborting.")
    return
end

-- obfuscated names look like  RE/<64 hex chars>
local function isHashName(n)
    local hex = n:match("^RE/(%x+)$")
    return hex ~= nil and #hex >= 32
end

local candidates = {}
for _, d in ipairs(Net:GetDescendants()) do
    if d:IsA("RemoteEvent") and isHashName(d.Name) then
        table.insert(candidates, d)
    end
end
print(("[Find] Probing %d hash-named RemoteEvents…"):format(#candidates))
if #candidates == 0 then
    warn("[Find] No hash-named RemoteEvents found. Aborting.")
    return
end

local MARKER = "PHIFIND" .. tostring(math.random(100000, 999999))
local function popupHasMarker()
    local m = MARKER:lower()
    for _, d in ipairs(PG:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and string.find((d.Text or ""):lower(), m, 1, true) then
            return true
        end
    end
    return false
end

local found
for _, re in ipairs(candidates) do
    pcall(function()
        firesignal(re.OnClientEvent, MARKER .. " announcement test", 4, "Sounds.Sfx.Blop", "Top", 2678001507)
    end)
    task.wait(0.15)
    if popupHasMarker() then found = re; break end
end

print("==========================================")
if found then
    _G.PhiNotifyRemote = found
    print("[Find] ✅ NOTIFY REMOTE FOUND:")
    print("[Find]    " .. found.Name)
    print("[Find] Saved to _G.PhiNotifyRemote (notify_test.lua will use it).")
else
    warn("[Find] ❌ No remote produced a popup with the marker.")
    warn("[Find] The payload shape may differ, or the popup label is hidden.")
    warn("[Find] Tell me and I'll widen the probe (e.g. include all RemoteEvents).")
end
print("==========================================")
