-- ============================================================
-- PHI NOTIFY TEST
-- Fires a FAKE announcement locally through the suspected notify
-- remote and lets you confirm its identity two ways:
--   1) does the game draw a notification popup on screen?  -> it IS the notify remote
--   2) does Phi catch the embedded code?                   -> Phi is listening correctly
-- Nothing is sent to the server; this only triggers client-side handlers.
-- NOTE: the hashed name rotates — paste the CURRENT locked name below.
-- ============================================================

local RS  = game:GetService("ReplicatedStorage")
local Net = RS:WaitForChild("Packages"):WaitForChild("Net")

-- <<< current locked notify remote name (from "[Phi] Notify locked ->") >>>
local NAME = "RE/7a01d0e095cd7447090a56f564aa2b6555f95cafba62aa048e1542b4d52d4272"

local remote = Net:FindFirstChild(NAME)
if not remote then
    warn("[Test] Remote not found — it probably rotated. Re-run Phi, copy the new")
    warn("[Test] '[Phi] Notify locked ->' name, and paste it into NAME above.")
    return
end
if typeof(firesignal) ~= "function" then
    warn("[Test] Your executor has no 'firesignal'. Can't fake an inbound event.")
    return
end

local code = "TESTCODE" .. tostring(math.random(1000, 9999))
local msg  = "TEST ANNOUNCEMENT — redeem " .. code .. " right now lol"

print("=========================================")
print("[Test] Firing fake announcement through:")
print("[Test]   " .. remote.Name)
print("[Test] embedded code = " .. code)
print("[Test] WATCH FOR:")
print("[Test]   1) a notification popup on screen with the message above")
print("[Test]   2) Phi status / console catching " .. code)
print("=========================================")

-- same payload shape your RemoteSpy showed: (text, duration, sound, position, soundId)
firesignal(remote.OnClientEvent,
    msg,
    5.5,
    "Sounds.Sfx.Blop",
    "Top",
    2678001507
)

print("[Test] sent. If NO popup appeared, this remote is NOT the notification one.")
