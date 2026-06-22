-- ============================================================
-- PHI NOTIFY TEST  (real popup)
-- Fires a FAKE announcement through the ACTUAL notify remote so the
-- game draws a real popup AND Phi catches it.
--
-- It auto-uses the remote Phi locked onto (_G.PhiNotifyRemote), so you
-- never paste a hash. Just:
--   1) load Phi
--   2) make sure it has LOCKED the notify remote (green dot / console
--      "[Phi] Notify locked ->") — that happens on the first real
--      announcement. If it hasn't locked yet, wait for one, or set
--      FALLBACK_NAME below to the locked-remote name.
--   3) run this — it posts the code word-by-word.
-- Nothing is sent to the server; this only triggers client handlers.
-- ============================================================

local RS  = game:GetService("ReplicatedStorage")
local Net = RS:WaitForChild("Packages"):WaitForChild("Net")

-- optional manual fallback (only used if Phi hasn't locked yet) — paste
-- the name from "[Phi] Notify locked ->", NOT a line from the probe.
local FALLBACK_NAME = ""

-- the words the "owner" will post, one announcement each (joined = code)
local WORDS = { "octo", "1234" }       -- WORDS=2 -> octo1234
local GAP   = 0.8                      -- seconds between each word

-- pick the remote: Phi's locked one first, else the fallback name
local remote = _G.PhiNotifyRemote
if not remote and FALLBACK_NAME ~= "" then remote = Net:FindFirstChild(FALLBACK_NAME) end

if not remote then
    warn("[Test] No notify remote yet. Load Phi and let it LOCK first")
    warn("[Test] (green dot / console '[Phi] Notify locked ->'), then re-run.")
    warn("[Test] Or paste that locked name into FALLBACK_NAME above.")
    return
end
if typeof(firesignal) ~= "function" then
    warn("[Test] Your executor has no 'firesignal'. Can't fake an inbound event.")
    return
end

print("[Test] Using remote:", remote.Name)
print("[Test] Posting code word-by-word:", table.concat(WORDS, " + "), "=", table.concat(WORDS))
print("[Test] Make sure LISTEN is ON and WORDS = " .. #WORDS)

task.spawn(function()
    for i, w in ipairs(WORDS) do
        firesignal(remote.OnClientEvent, w, 5.5, "Sounds.Sfx.Blop", "Top", 2678001507)
        print("[Test] posted word " .. i .. "/" .. #WORDS .. ": " .. w)
        task.wait(GAP)
    end
    print("[Test] done. A popup should have shown for each word.")
end)
