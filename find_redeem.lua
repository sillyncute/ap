-- ============================================================
-- PHI REDEEM FINDER
-- Finds the REAL redeem remote the same way we found notify: by the
-- game code that uses it. Redeeming is OUTBOUND (a RemoteFunction the
-- client INVOKES), so we scan for the controller that handles codes/
-- redemption and pull the RemoteFunction it calls.
--
-- Needs: getgc + debug.getinfo (+ getupvalues/getconstants).
-- Prints every candidate RemoteFunction + the script that uses it, so
-- you can see which one is the true redeem (and tell me the name).
-- ============================================================

local dbg       = debug or {}
local getinfo   = dbg.getinfo or dbg.info
local getups    = dbg.getupvalues or getupvalues
local getconsts = dbg.getconstants or getconstants

if not (getgc and getinfo) then
    warn("[Redeem] needs getgc + debug.getinfo — not available in this executor.")
    return
end

-- controller scripts likely to handle code redemption
local KEYWORDS = { "redemption", "redeem", "promocode", "promo", "codecontroller", "code" }
local function srcKeyword(src)
    src = src:lower()
    for _, k in ipairs(KEYWORDS) do if src:find(k, 1, true) then return k end end
end

local function collectRFs(list, depth, out)
    for _, v in pairs(list) do
        if typeof(v) == "Instance" and v:IsA("RemoteFunction") then out[v] = true
        elseif type(v) == "table" and depth > 0 then collectRFs(v, depth - 1, out) end
    end
end

local results = {}      -- rf -> { [src]=keyword }
for _, fn in ipairs(getgc(true)) do
    if type(fn) == "function" then
        local ok, info = pcall(getinfo, fn)
        if ok and type(info) == "table" then
            local src = tostring(info.short_src or info.source or "")
            local kw  = srcKeyword(src)
            if kw then
                local out = {}
                if getups    then local k, u = pcall(getups, fn);    if k then collectRFs(u, 1, out) end end
                if getconsts then local k, c = pcall(getconsts, fn); if k then collectRFs(c, 1, out) end end
                for rf in pairs(out) do
                    results[rf] = results[rf] or {}
                    results[rf][src] = kw
                end
            end
        end
    end
end

print("==========================================")
local n = 0
for rf, srcs in pairs(results) do
    n += 1
    print("[Redeem] candidate RemoteFunction:")
    print("[Redeem]    " .. rf.Name)
    for src, kw in pairs(srcs) do print(("[Redeem]      used by: %s   (matched '%s')"):format(src, kw)) end
end
if n == 0 then
    warn("[Redeem] No RemoteFunction found near a code/redemption controller.")
    warn("[Redeem] Tell me and I'll widen the keywords or inspect another way.")
else
    -- if exactly one, publish it for convenience
    for rf in pairs(results) do if n == 1 then _G.PhiRedeemRemote = rf; print("[Redeem] saved single match to _G.PhiRedeemRemote") end end
    print("[Redeem] If several show, the real one is usually the RF under the code/redeem controller.")
end
print("==========================================")
