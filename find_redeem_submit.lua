-- ============================================================
-- PHI REDEEM CAPTURE  (click Submit to reveal it)
-- The surest way to find the redeem remote: watch what the game itself
-- invokes when YOU press Submit in the Codes UI.
--
-- 1) run this
-- 2) type ANY code in the game's Codes box and press Submit
-- 3) it prints the exact RemoteFunction the game used = the redeem remote
--
-- Uses a one-time namecall hook that becomes pass-through after the
-- capture (rejoin the game to clear it fully if you want).
-- ============================================================

if not (hookmetamethod and getnamecallmethod) then
    warn("[Cap] needs hookmetamethod + getnamecallmethod — not available here.")
    warn("[Cap] Run find_redeem.lua instead (GC scan).")
    return
end

print("==========================================")
print("[Cap] READY. Now type any code in the game's Codes box and press Submit.")
print("[Cap] (waiting for the game to invoke a RemoteFunction…)")
print("==========================================")

local captured = false
local old
old = hookmetamethod(game, "__namecall", function(self, ...)
    if not captured and getnamecallmethod() == "InvokeServer"
       and typeof(self) == "Instance" and self:IsA("RemoteFunction") then
        local arg1 = (...)
        if typeof(arg1) == "string" and #arg1 >= 1 then
            captured = true
            _G.PhiRedeemRemote = self
            print("==========================================")
            print("[Cap] ✅ REDEEM REMOTE =", self.Name)
            print("[Cap] invoked with: \"" .. tostring(arg1) .. "\"")
            print("[Cap] is RequestRedemption? ->", self.Name:find("Redemption") ~= nil)
            print("[Cap] saved to _G.PhiRedeemRemote")
            print("==========================================")
        end
    end
    return old(self, ...)
end)
