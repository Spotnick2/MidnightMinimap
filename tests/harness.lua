-- harness.lua: loads MidnightMinimap into the stub. After tests/wow_stubs.lua.
-- check / eq / done are WowTestKit's (global).

TOC = "MidnightMinimap.toc"

-- A fresh client (WoW.reset: new Blizzard frames, the client's state back to
-- the stub's), the saved variables as given, then the TOC's files in order
-- and the login. opts.before(): runs after the reset, before the load
-- (settings, a hidden map...).
function loadAddon(saved, opts)
    opts = opts or {}
    WoW.reset()
    MidnightMinimapDB = saved
    if opts.before then opts.before() end
    for _, file in ipairs(Kit.tocFiles(TOC)) do dofile(file) end
    WoW.fire("PLAYER_LOGIN")
end

-- Every widget (frames and their regions), for checks over all of them.
function allWidgets()
    local list, seen = {}, {}
    local function add(w)
        if seen[w] then return end
        seen[w] = true
        list[#list + 1] = w
        for _, r in ipairs(w._regions or {}) do add(r) end
    end
    for _, f in ipairs(WoW.frames) do add(f) end
    return list
end

-- The last line the addon printed.
function lastPrint()
    return WoW.chat[#WoW.chat]
end
