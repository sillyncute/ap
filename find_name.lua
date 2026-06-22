-- ============================================================
-- PHI REMOTE NAME FINDER
-- The hashed name (RE/<hash>) can't be reversed — it's salted. But the
-- game's own code that LISTENS to the remote usually still carries the
-- readable logical name (as a string constant) and definitely lives in
-- a named script. This inspects the functions connected to the remote
-- and the code around it to surface that "real" name.
--
-- Needs executor debug tools: getconnections + debug.getconstants /
-- getupvalues / getinfo. Run find_remote.lua first (sets _G.PhiNotifyRemote).
-- ============================================================

local remote = _G.PhiNotifyRemote
if not remote then
    warn("[Name] _G.PhiNotifyRemote not set — run find_remote.lua first.")
    return
end
print("==========================================")
print("[Name] Inspecting:", remote.Name)

local dbg = debug or {}
local getconsts = dbg.getconstants or getconstants
local getups    = dbg.getupvalues  or getupvalues
local getinfo   = dbg.getinfo or dbg.info or getinfo

local function readable(s)
    if type(s) ~= "string" or #s < 3 or #s > 100 then return false end
    if s == remote.Name then return false end
    if s:match("^RE/%x+$") or s:match("^RF/%x+$") then return false end  -- another hash
    return s:match("%a") ~= nil                                          -- has letters
end

local seen = {}
local function report(tag, s)
    if readable(s) and not seen[s] then seen[s] = true; print("   " .. tag .. ": " .. s) end
end

local function scanFn(fn, label)
    if type(fn) ~= "function" then return end
    if getinfo then
        local ok, info = pcall(getinfo, fn)
        if ok and type(info) == "table" then
            print(("  [%s] script=%s  name=%s  line=%s"):format(
                label, tostring(info.short_src or info.source), tostring(info.name), tostring(info.linedefined)))
        end
    end
    if getconsts then
        local ok, cs = pcall(getconsts, fn)
        if ok then for _, k in pairs(cs) do report("const", k) end end
    end
    if getups then
        local ok, ups = pcall(getups, fn)
        if ok then for _, u in pairs(ups) do
            if type(u) == "string" then report("upval", u)
            elseif type(u) == "table" then
                for k in pairs(u) do report("table-key", k) end   -- logical-name -> handler maps
            end
        end end
    end
end

-- 1) functions directly connected to OnClientEvent
if getconnections then
    local conns = getconnections(remote.OnClientEvent)
    print(("[Name] %d connection(s) on OnClientEvent:"):format(#conns))
    for i, c in ipairs(conns) do
        local ok, fn = pcall(function() return c.Function end)
        scanFn(ok and fn or nil, "conn#" .. i)
    end
else
    warn("[Name] getconnections not available — skipping connection scan.")
end

-- 2) GC scan: any function that references this exact remote, dump its readable strings
if getgc and getconsts then
    print("[Name] GC scan for code that references the remote…")
    for _, fn in ipairs(getgc(true)) do
        if type(fn) == "function" then
            local related = false
            if getups then
                local ok, ups = pcall(getups, fn)
                if ok then for _, u in pairs(ups) do if u == remote then related = true break end end end
            end
            if not related then
                local ok, cs = pcall(getconsts, fn)
                if ok then for _, k in pairs(cs) do if k == remote or k == remote.Name then related = true break end end end
            end
            if related then scanFn(fn, "gc-ref") end
        end
    end
end

print("[Name] done — the logical name is usually the script= path or a 'const'/'table-key' above.")
print("==========================================")
