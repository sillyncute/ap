-- ============================================================
-- PHI NOTIFY TEST  (word-by-word)
-- Fires FAKE announcements locally through the notify remote so
-- you can test the LISTEN flow:
--   1) load Phi, open the LIVE FEED
--   2) press F (LISTEN turns on), set WORDS to match (e.g. 2 or 3)
--   3) run this script -> it posts the code one word at a time
--   4) watch the status count up (1/N, 2/N...) then insta-redeem
-- Nothing is sent to the server; this only triggers client handlers.
-- NOTE: the hashed name rotates — paste the CURRENT locked name below.
-- ============================================================

local RS  = game:GetService("ReplicatedStorage")
local Net = RS:WaitForChild("Packages"):WaitForChild("Net")

-- <<< current locked notify remote name (from "[Phi] Notify locked ->") >>>
local NAME = "RE/7a01d0e095cd7447090a56f564aa2b6555f95cafba62aa048e1542b4d52d4272"

-- the words the "owner" will post, one announcement each (joined = the code)
local WORDS = { "octo", "1234" }       -- e.g. WORDS=2 -> octo1234
local GAP   = 0.8                      -- seconds between each word

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

print("[Test] Posting code word-by-word:", table.concat(WORDS, " + "), "=", table.concat(WORDS))
print("[Test] Make sure LISTEN (F) is ON and WORDS = " .. #WORDS)

task.spawn(function()
    for i, w in ipairs(WORDS) do
        firesignal(remote.OnClientEvent, w, 5.5, "Sounds.Sfx.Blop", "Top", 2678001507)
        print("[Test] posted word " .. i .. "/" .. #WORDS .. ": " .. w)
        task.wait(GAP)
    end
    print("[Test] done. Phi should have assembled '" .. table.concat(WORDS) .. "' and fired.")
end)
