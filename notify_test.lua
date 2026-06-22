-- ============================================================
-- PHI NOTIFY TEST  (feed + listen)
-- Fires FAKE announcements through the ACTUAL notify remote so the game
-- draws real popups AND Phi catches them into the LIVE FEED.
--
-- Auto-uses the remote Phi locked on load (_G.PhiNotifyRemote) — no hash.
-- Just load Phi first, then run this.
--
--   • To test the FEED:   open the LIVE FEED, run this, watch it fill.
--   • To test LISTEN:     turn LISTEN on + set WORDS=2, then run this —
--                         "octo" + "1234" assemble into OCTO1234 and fire.
-- firesignal is LOCAL — nothing reaches the server.
-- ============================================================

local RS  = game:GetService("ReplicatedStorage")
local Net = RS:WaitForChild("Packages"):WaitForChild("Net")

-- only used if Phi hasn't locked the remote yet (paste the locked name)
local FALLBACK_NAME = ""

-- the announcements to fire, in order, one per line
local MESSAGES = {
    "octo",
    "1234",
    "GET THIS CODE everyone redeem fast",
    "FREEGEMS2024",
}
local GAP = 0.8   -- seconds between each

local remote = _G.PhiNotifyRemote
if not remote and FALLBACK_NAME ~= "" then remote = Net:FindFirstChild(FALLBACK_NAME) end
if not remote then
    warn("[Test] No notify remote yet. Load Phi first (it finds it on load via")
    warn("[Test] NotificationController), then re-run. Or set FALLBACK_NAME above.")
    return
end
if typeof(firesignal) ~= "function" then
    warn("[Test] Your executor has no 'firesignal'. Can't fake an inbound event.")
    return
end

print("[Test] Using remote:", remote.Name)
print("[Test] Firing " .. #MESSAGES .. " announcement(s)…")

task.spawn(function()
    for i, msg in ipairs(MESSAGES) do
        firesignal(remote.OnClientEvent, msg, 5.5, "Sounds.Sfx.Blop", "Top", 2678001507)
        print("[Test] sent " .. i .. "/" .. #MESSAGES .. ": " .. msg)
        task.wait(GAP)
    end
    print("[Test] done — check the LIVE FEED.")
end)
