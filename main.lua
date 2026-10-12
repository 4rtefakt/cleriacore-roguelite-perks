-- Roguelite Perks: a boss beaten = one perk to choose among three, kept with the save.
-- Each perk is one rule over the mod API; the table below is the whole design.

local S, P, G = cleria.settings, cleria.player, cleria.game

local PERKS = {   -- key, name, the most you can stack, what one stack does
    {"might", "Might", 5, "+8% ATK"},
    {"guard", "Guard", 5, "+8% DEF"},
    {"vigor", "Vigor", 6, "+15 max HP"},
    {"leech", "Leech", 3, "Each kill heals 2 HP"},
    {"scavenger", "Scavenger", 3, "+10% chance that a kill drops a Recovery Drop"},
    {"greed", "Greed", 3, "+20% SP from kills and gold"},
    {"scholar", "Scholar", 3, "+15% EXP"},
    {"lingering", "Lingering", 2, "Strength, Defense and MP Drop buffs last 50% longer"},
    {"secondwind", "Second Wind", 1, "Once per room, a hit that would kill you leaves you at 1 HP"},
}
local BY = {}
for _, p in ipairs(PERKS) do BY[p[1]] = p end

local start_perk = S.get("StartPerk", true)    -- a new game begins with one perk to choose
local auto = S.get("AutoPick", false)          -- take one of the three at random, no menu
local show = S.get("Show", true)

-- Kept with the save: what is owned, how many choices are waiting, and the three on offer
-- (stored, so a reload does not reroll them).
local st = {owned = {}, pending = 0, offer = {}}
local wind_used = false

local function n(key) return st.owned[key] or 0 end
local function keep() if cleria.save.ready() then cleria.save.set("perks", st) end end

local function apply()
    if not G.in_game() then return end
    P.set_modifier("atk", 0, 1 + 0.08 * n("might"))
    P.set_modifier("def", 0, 1 + 0.08 * n("guard"))
    P.set_modifier("max_hp", 15 * n("vigor"), 1)
end

local function roll()                           -- three different perks that can still be stacked
    local pool = {}
    for _, p in ipairs(PERKS) do if n(p[1]) < p[3] then pool[#pool + 1] = p[1] end end
    st.offer = {}
    while #st.offer < 3 and #pool > 0 do st.offer[#st.offer + 1] = table.remove(pool, math.random(#pool)) end
    if #st.offer == 0 then st.pending = 0 end   -- everything is maxed
end

local function take(i)
    local key = st.offer[i]
    if st.pending <= 0 or not key then return false end
    st.owned[key] = n(key) + 1
    st.pending = st.pending - 1
    cleria.notice(BY[key][2] .. (BY[key][3] > 1 and (" " .. n(key)) or "") .. ": " .. BY[key][4], "Perk taken")
    cleria.log("took " .. key .. " (" .. n(key) .. ")")
    st.offer = {}
    if st.pending > 0 then roll() end
    apply()
    keep()
    return true
end

local function earn(why)
    st.pending = st.pending + 1
    if #st.offer == 0 then roll() end
    if st.pending == 0 then return end
    cleria.log("perk earned (" .. why .. "): " .. table.concat(st.offer, ", "))
    if auto then
        take(math.random(#st.offer))
    else
        cleria.notice("Choose it in F1 > Mods > Roguelite Perks", "Perk earned")
        keep()
    end
end

local function restore(new)
    local t = cleria.save.get("perks")
    st = {owned = {}, pending = 0, offer = {}}
    if type(t) == "table" then
        for k, v in pairs(type(t.owned) == "table" and t.owned or {}) do if BY[k] then st.owned[k] = math.tointeger(v) or 0 end end
        st.pending = math.tointeger(t.pending) or 0
        for _, k in ipairs(type(t.offer) == "table" and t.offer or {}) do if BY[k] then st.offer[#st.offer + 1] = k end end
    end
    wind_used = false
    apply()
    if new and start_perk then earn("a new game") end
end
cleria.events.on("new_game", function() restore(true) end)
cleria.events.on("load", function() restore(false) end)
cleria.events.on("boss_defeated", function() earn("a boss fell") end)
cleria.events.on("room_enter", function() wind_used = false end)
cleria.events.on("death", function() wind_used = false end)       -- a Retry raises no room_enter

-- ---- the perks that are not a stat -----------------------------------------------------------------------------
cleria.events.on("enemy_killed", function(e)
    if n("leech") > 0 then
        local hp, max = P.hp(), P.max_hp()
        if hp > 0 and hp < max then P.set_hp(math.min(max, hp + 2 * n("leech"))) end
    end
    if n("scavenger") > 0 and math.random(100) <= 10 * n("scavenger") then
        G.spawn_pickup(0x42, e.x, e.y, e.z)
    end
end)
cleria.combat.add_filter("sp", function(q)
    if n("greed") > 0 and (q.source == "kill" or q.source == "pickup") then
        return math.floor(q.value * (1 + 0.2 * n("greed")) + 0.5)
    end
end)
cleria.combat.add_filter("exp", function(q)
    if n("scholar") > 0 then return q.value * (1 + 0.15 * n("scholar")) end
end)
cleria.combat.add_filter("pickup", function(q)
    if n("lingering") > 0 and q.ticks and q.ticks > 0 then
        return {action = "replace", ticks = math.floor(q.ticks * (1 + 0.5 * n("lingering")))}
    end
end)
cleria.combat.add_filter("damage", function(q)
    if q.dir ~= "taken" or n("secondwind") == 0 or wind_used then return nil end
    local hp = P.hp()
    if hp > 1 and q.value >= hp then
        wind_used = true
        cleria.notice("You hold on at 1 HP.", "Second Wind")
        return hp - 1
    end
end)

-- ---- the page and the corner line ------------------------------------------------------------------------------
local function owned_text()
    local t = {}
    for _, p in ipairs(PERKS) do
        if n(p[1]) > 0 then t[#t + 1] = p[2] .. (p[3] > 1 and (" " .. n(p[1])) or "") end
    end
    return #t > 0 and table.concat(t, "  -  ") or nil
end

cleria.ui.page("Roguelite Perks", function(p)
    p:section("Choose a perk")
    if st.pending > 0 and #st.offer > 0 then
        p:info("Waiting", st.pending .. (st.pending == 1 and " choice" or " choices"), {color = "good"})
        for i, key in ipairs(st.offer) do
            local k = BY[key]
            if p:button(k[2] .. (k[3] > 1 and (" " .. (n(key) + 1) .. " / " .. k[3]) or ""), k[4] .. ".") then take(i) end
        end
    else
        p:info("Nothing to choose", "", "Beat a boss, a mid-boss or a duel to earn a perk.")
    end
    p:section("Your perks")
    local any = false
    for _, k in ipairs(PERKS) do
        if n(k[1]) > 0 then
            any = true
            p:info(k[2], k[3] > 1 and (n(k[1]) .. " / " .. k[3]) or "owned", k[4] .. (k[3] > 1 and " per stack." or "."))
        end
    end
    if not any then p:info("None yet", "") end
    p:section("Options")
    local v, ch = p:toggle("Start with a perk", start_perk, "A new game begins with one perk to choose.")
    if ch then start_perk = v S.set("StartPerk", v) end
    v, ch = p:toggle("Pick for me", auto, "Takes one of the three at random as soon as it is earned.")
    if ch then auto = v S.set("AutoPick", v) end
    v, ch = p:toggle("Show in the corner", show, "Your perks, and a reminder when a choice is waiting.")
    if ch then show = v S.set("Show", v) end
end)

cleria.hud.layer("perks", function(d)
    if not show or not G.in_game() then return end
    local s = d.scale
    local lines = {}
    if st.pending > 0 then lines[#lines + 1] = {"Perk to choose: F1 > Mods > Roguelite Perks", "good"} end
    local o = owned_text()
    if o then lines[#lines + 1] = {o, "label"} end
    for i, l in ipairs(lines) do
        local w = d:text_size(l[1], {size = 18 * s, font = "cond_medium"})
        local y = 14 * s + (i - 1) * 36 * s
        d:rect(14 * s, y, w + 24 * s, 32 * s, {color = 0x100F0B, alpha = 0.7, rounding = 4 * s})
        d:text(26 * s, y + 6 * s, l[1], {size = 18 * s, color = l[2], font = "cond_medium"})
    end
end)

-- ---- test commands: "perk" (state), "perk pick <i>", "perk give <key>" -----------------------------------------
cleria.command("perk", function(a)
    local cmd, arg = a:match("^(%S+)%s*(%S*)")
    if cmd == "pick" then take(tonumber(arg) or 1)
    elseif cmd == "give" and BY[arg] then st.owned[arg] = math.min(BY[arg][3], n(arg) + 1) apply() keep() end
    local st2 = P.stats()
    cleria.log(string.format("pending %d offer %d owned [%s] atk %g def %g hp %.0f/%.0f", st.pending, #st.offer, owned_text() or "",
                             st2.atk, st2.def, st2.hp, st2.max_hp))
end)
cleria.log("Roguelite Perks loaded")
