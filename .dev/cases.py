def kill(cast, start, n=4):
    return ";".join("%d:near=%d;%d:atk" % (t, cast, t + 1) for t in range(start, start + 25 * n, 25))


LP = "[lua:4rtefakt.perks] "
CASES = {
    # A new game offers three perks; picking one applies it; a boss beaten (its flag) earns the next choice;
    # the state comes back from a save and load.
    "earn_and_pick": dict(room="S_10/S_1009/S_1009",
        drive="30:lua=perk;40:lua=perk pick 1;50:lua=perk;60:flag=220,1;90:lua=perk;100:saveload;140:lua=perk;141:shot;150:quit",
        expect=[LP + "perk earned (a new game): ", "notice Perk earned: Choose it in F1 > Mods > Roguelite Perks",
                LP + "pending 1 offer 3 owned [] atk 46 def 38 hp 60/60", LP + "took ", LP + "pending 0 offer 0 owned [",
                LP + "perk earned (a boss fell): ", LP + "pending 1 offer 3 owned [", LP + "pending 1 offer 3 owned ["],
        shots={"hud": 141}),
    # The stats: Might +8% ATK (46 -> 49.68), Guard +8% DEF (38 -> 41.04), Vigor +15 max HP, stacking.
    "stats": dict(room="S_10/S_1002/S_1002", settings="StartPerk=0",
        drive="20:lua=perk give might;30:lua=perk give guard;40:lua=perk give vigor;50:lua=perk give vigor;60:quit",
        expect=[LP + "pending 0 offer 0 owned [Might 1] atk 49.68 def 38 hp 60/60",
                "owned [Might 1  -  Guard 1] atk 49.68 def 41.04 hp 60/60",
                "owned [Might 1  -  Guard 1  -  Vigor 1] atk 49.68 def 41.04 hp 60/75",
                "Vigor 2] atk 49.68 def 41.04 hp 60/90"]),
    # Leech: a kill at 10 HP heals 2. Scholar: the kill's 50.96 EXP x 1.15 = 58.6. Greed: its 4 SP x 1.2 = 5.
    "kill_perks": dict(room="S_10/S_1002/S_1002", settings="StartPerk=0",
        drive="6:hp=10;8:opt=DamageDealt=10;10:opt=DamageTaken=0;12:lua=perk give leech;13:lua=perk give scholar;14:lua=perk give greed;"
              + kill(17, 40) + ";145:lua=perk;146:stats;150:quit",
        expect=["owned [Leech 1  -  Greed 1  -  Scholar 1] atk 46 def 38 hp 12/60", "stats exp 59 lv 1 hp 12/60 sp 5"]),
    # Second Wind: a hit far above the HP leaves 1 HP, once per room; the second one kills.
    "second_wind": dict(room="S_10/S_1002/S_1002", settings="StartPerk=0",
        drive="12:lua=perk give secondwind;30:hurt=400;40:stats;240:hurt=400;250:stats;300:quit",
        expect=["notice Second Wind: You hold on at 1 HP.", "hp 1/60", "[death] HP 0"]),
    "no_second_wind": dict(room="S_10/S_1002/S_1002", settings="StartPerk=0",
        drive="30:hurt=400;40:stats;80:quit", expect=["[death] HP 0"], absent=["Second Wind"]),
}
