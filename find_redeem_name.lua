-- ============================================================
-- PHI REDEEM NAME FINDER
-- Reveals the readable logical name + controller behind the hashed
-- redeem RemoteFunction, by inspecting the game code that invokes it.
-- Run find_redeem_submit.lua first (sets _G.PhiRedeemRemote).
-- Needs: getgc + debug.getinfo (+ getconstants/getupvalues).
-- ============================================================

local remote = _G.PhiRedeemRemote
if not remote then
    warn("[Name] _G.PhiRedeemRemote not set — run find_redeem_submit.lua first")
    warn("[Name] (then press Submit on a code so it captures the remote).")
    return
end
print("==========================================")
print("[Name] Inspecting redeem remote:", remote.Name)

local dbg       = debug or {}
local getinfo   = dbg.getinfo or dbg.info
local getups    = dbg.getupvalues or getupvalues
local getconsts = dbg.getconstants or getconstants
if not (getgc and getinfo) then
    warn("[Name] needs getgc + debug.getinfo — not available here.")
    return
end

local function readable(s)
    if type(s) ~= "string" or #s < 3 or #s > 100 then return false end
    if s == remote.Name then return false end
    if s:match("^R[EF]/%x+$") then return false end     -- another hash
    return s:match("%a") ~= nil
end
local seen = {}
local function report(tag, s)
    if readable(s) and not seen[s] then seen[s] = true; print("   " .. tag .. ": " .. s) end
end

local function scanFn(fn, label)
    local ok, info = pcall(getinfo, fn)
    if ok and type(info) == "table" then
        print(("  [%s] script=%s  name=%s  line=%s"):format(
            label, tostring(info.short_src or info.source), tostring(info.name), tostring(info.linedefined)))
    end
    if getconsts then local k, cs = pcall(getconsts, fn); if k then for _, c in pairs(cs) do report("const", c) end end end
    if getups   then local k, ups = pcall(getups, fn);    if k then for _, u in pairs(ups) do
        if type(u) == "string" then report("upval", u)
        elseif type(u) == "table" then for kk in pairs(u) do report("table-key", kk) end end
    end end
end

print("[Name] scanning code that references the redeem remote…")
local hits = 0
for _, fn in ipairs(getgc(true)) do
    if type(fn) == "function" then
        local related = false
        if getups then local k, ups = pcall(getups, fn); if k then for _, u in pairs(ups) do if u == remote then related = true break end end end end
        if not related and getconsts then local k, cs = pcall(getconsts, fn); if k then for _, c in pairs(cs) do if c == remote or c == remote.Name then related = true break end end end end
        if related then scanFn(fn, "ref"); hits += 1 end
    end
end
if hits == 0 then warn("[Name] no referencing code found — tell me and I'll try another route.") end
print("[Name] done — the real name is the script= path or a const/table-key above.")
print("==========================================")
