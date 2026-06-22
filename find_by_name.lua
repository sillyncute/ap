-- ============================================================
-- PHI NAME-BASED FINDER  (deterministic, no probing)
-- We learned the notify remote is handled by NotificationController.
-- That script connects to the remote every session, so we can pull the
-- RemoteEvent straight out of the controller's code — no firing, no
-- waiting, works no matter how the hash rotates.
--
-- Needs: getgc + debug.getinfo (+ getupvalues/getconstants).
-- Saves the result to _G.PhiNotifyRemote.
-- ============================================================

local dbg       = debug or {}
local getinfo   = dbg.getinfo or dbg.info
local getups    = dbg.getupvalues or getupvalues
local getconsts = dbg.getconstants or getconstants

if not (getgc and getinfo) then
    warn("[ByName] needs getgc + debug.getinfo — not available in this executor.")
    return
end

local CONTROLLER = "NotificationController"

-- pull a hash-named RemoteEvent (RE/<hash>) out of a value list
local function pickRemote(list)
    for _, v in pairs(list) do
        if typeof(v) == "Instance" and v:IsA("RemoteEvent") and v.Name:match("^RE/%x+$") then
            return v
        end
    end
end

local function remoteFrom(fn)
    if getups then
        local ok, ups = pcall(getups, fn)
        if ok then local r = pickRemote(ups); if r then return r end end
    end
    if getconsts then
        local ok, cs = pcall(getconsts, fn)
        if ok then local r = pickRemote(cs); if r then return r end end
    end
end

local found
for _, fn in ipairs(getgc(true)) do
    if type(fn) == "function" then
        local ok, info = pcall(getinfo, fn)
        if ok and type(info) == "table" then
            local src = tostring(info.short_src or info.source or "")
            if src:find(CONTROLLER, 1, true) then
                local re = remoteFrom(fn)
                if re then found = re; break end
            end
        end
    end
end

print("==========================================")
if found then
    _G.PhiNotifyRemote = found
    print("[ByName] ✅ notify remote (via " .. CONTROLLER .. "):")
    print("[ByName]    " .. found.Name)
    print("[ByName] Saved to _G.PhiNotifyRemote.")
else
    warn("[ByName] ❌ couldn't pull the remote from " .. CONTROLLER .. ".")
    warn("[ByName] The controller may capture it differently — use find_remote.lua,")
    warn("[ByName] or tell me and I'll adjust the scan.")
end
print("==========================================")
