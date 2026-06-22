-- ============================================================
-- PHI NOTIFY TEST  (real remote, auto-found)
-- Fires ONE fake announcement (with an embedded TESTCODE) through the
-- ACTUAL notify remote. Confirm two ways:
--   1) does a notification popup appear on screen?  -> it IS the remote
--   2) does Phi catch the embedded code?            -> Phi is listening
-- Auto-resolves the real remote (no hash to paste): uses the one Phi
-- locked (_G.PhiNotifyRemote), else finds it via NotificationController.
-- firesignal is LOCAL — nothing reaches the server.
-- ============================================================

local RS  = game:GetService("ReplicatedStorage")
local Net = RS:WaitForChild("Packages"):WaitForChild("Net")

-- 1) prefer the remote Phi already locked
local remote = _G.PhiNotifyRemote

-- 2) else find it ourselves via NotificationController (deterministic)
if not remote then
    local getinfo   = debug and (debug.getinfo or debug.info)
    local getups    = (debug and debug.getupvalues) or getupvalues
    local getconsts = (debug and debug.getconstants) or getconstants
    if getgc and getinfo then
        local function pick(list)
            for _, v in pairs(list) do
                if typeof(v) == "Instance" and v:IsA("RemoteEvent") and v.Name:match("^RE/%x+$") then return v end
            end
        end
        for _, fn in ipairs(getgc(true)) do
            if type(fn) == "function" then
                local ok, info = pcall(getinfo, fn)
                if ok and type(info) == "table" then
                    local src = tostring(info.short_src or info.source or "")
                    if src:find("NotificationController", 1, true) then
                        if getups then local k, ups = pcall(getups, fn); if k then remote = pick(ups) end end
                        if not remote and getconsts then local k, cs = pcall(getconsts, fn); if k then remote = pick(cs) end end
                        if remote then break end
                    end
                end
            end
        end
    end
end

if not remote then
    warn("[Test] Couldn't resolve the notify remote. Load Phi first (it sets")
    warn("[Test] _G.PhiNotifyRemote on load), then re-run this.")
    return
end
if typeof(firesignal) ~= "function" then
    warn("[Test] Your executor has no 'firesignal'. Can't fake an inbound event.")
    return
end

local code = "TESTCODE" .. tostring(math.random(1000, 9999))
local msg  = "TEST ANNOUNCEMENT — redeem " .. code .. " right now lol"

print("=========================================")
print("[Test] Firing through REAL remote:")
print("[Test]   " .. remote.Name)
print("[Test] embedded code = " .. code)
print("[Test] WATCH FOR:")
print("[Test]   1) a notification popup on screen with the message above")
print("[Test]   2) Phi status / feed catching " .. code)
print("=========================================")

-- payload shape: (text, duration, sound, position, soundId)
firesignal(remote.OnClientEvent, msg, 5.5, "Sounds.Sfx.Blop", "Top", 2678001507)

print("[Test] sent. If NO popup appeared, this remote is NOT the notification one.")
