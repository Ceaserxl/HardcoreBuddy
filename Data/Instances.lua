-- Classic Era packing lists. Suggested full-run levels, not entrance requirements.
-- Research: reference/research/instances/README.md.
local _, A = ...
local D = {guides={}, tools={}}
A.Data.Instances = D
local function tool(id,name,level,description,icon,skill)
    D.tools[id]={itemId=id,name=name,level=level,description=description,icon="/images/"..icon..".jpg",skill=skill}
end
tool(2459,"Swiftness Potion",5,"50% run speed for 15 sec; does not break roots.","inv_potion_95")
tool(3387,"Limited Invulnerability Potion",45,"6 sec physical immunity; spells still hit.","inv_potion_62")
tool(3829,"Frost Oil",30,"Frostbolt weapon procs; Viscidus or tribute trap.","inv_potion_20")
tool(5634,"Free Action Potion",20,"30 sec stun/slow prevention; use before the effect.","inv_potion_04")
tool(6049,"Fire Protection Potion",23,"Absorbs 975-1625 fire damage.","inv_potion_16")
tool(6050,"Frost Protection Potion",28,"Absorbs 1350-2250 frost damage; no slow immunity.","inv_potion_13")
tool(6052,"Nature Protection Potion",28,"Absorbs 1350-2250 nature damage; no poison cleanse.","inv_potion_06")
tool(6452,"Anti-Venom",1,"Removes poisons up to poison level 25.","inv_misc_slime_01")
tool(6453,"Strong Anti-Venom",1,"Removes poisons up to poison level 35.","inv_misc_slime_01")
tool(9030,"Restorative Potion",32,"Removes one dispellable debuff every 5 sec.","inv_potion_01")
tool(13456,"Greater Frost Protection Potion",48,"Absorbs 1950-3250 frost damage; no slow immunity.","inv_potion_20")
tool(13457,"Greater Fire Protection Potion",48,"Absorbs 1950-3250 fire damage.","inv_potion_24")
tool(13458,"Greater Nature Protection Potion",48,"Absorbs 1950-3250 nature damage; no poison cleanse.","inv_potion_22")
tool(13459,"Greater Shadow Protection Potion",48,"Absorbs 1950-3250 shadow damage; no fear immunity.","inv_potion_23")
tool(13461,"Greater Arcane Protection Potion",48,"Absorbs 1950-3250 arcane damage.","inv_potion_83")
tool(15138,"Onyxia Scale Cloak",55,"Equip for Shadow Flame engulfment; initial damage still hits.","inv_misc_cape_05")
tool(15994,"Thorium Widget",1,"Tribute trap component; also bring Frost Oil.","inv_gizmo_04")
tool(18258,"Gordok Ogre Suit",55,"Disguise for Kromcrush on a planned tribute run.","inv_chest_chain_14")
tool(19183,"Hourglass Sand",1,"Removes Chromaggus' Bronze affliction.","inv_misc_dust_02")
tool(19440,"Powerful Anti-Venom",1,"Removes poisons up to poison level 60.","inv_drink_14","First Aid 300")

local function add(id,name,map,low,high,zone,pack,players,kind)
    D.guides[#D.guides+1]={id=id,name=name,map=map,low=low,high=high,zone=zone,
        pack=pack,players=players or 5,kind=kind or "dungeons"}
end

add("rfc","Ragefire Chasm",389,16,20,"Orgrimmar",{2459})
add("wc","Wailing Caverns",43,21,25,"Northern Barrens",{6452,6453,5634})
add("deadmines","The Deadmines",36,21,25,"Westfall",{2459})
add("sfk","Shadowfang Keep",33,25,30,"Silverpine Forest",{})
add("stockades","The Stockade",34,26,30,"Stormwind City",{5634,6052})
add("bfd","Blackfathom Deeps",48,27,32,"Ashenvale",{6453,6052,5634})
add("gnomer","Gnomeregan",90,33,38,"Dun Morogh",{6049,5634})
add("rfk","Razorfen Kraul",47,32,37,"Southern Barrens",{6052,5634})
add("sm-graveyard","Scarlet Monastery: Graveyard",189,32,36,"Tirisfal Glades",{6049,6453,9030})
add("sm-library","Scarlet Monastery: Library",189,35,39,"Tirisfal Glades",{9030})
add("sm-armory","Scarlet Monastery: Armory",189,38,42,"Tirisfal Glades",{})
add("sm-cathedral","Scarlet Monastery: Cathedral",189,41,45,"Tirisfal Glades",{9030})
add("rfd","Razorfen Downs",129,40,45,"Southern Barrens",{6050,9030})
add("uldaman","Uldaman",70,46,51,"Badlands",{6049,9030})
add("zf","Zul'Farrak",209,47,51,"Tanaris",{9030,6050,5634})
add("mara-purple","Maraudon: Purple",349,47,51,"Desolace",{9030})
add("mara-orange","Maraudon: Orange",349,47,51,"Desolace",{6052,13458,19440,9030})
add("mara-inner","Maraudon: Inner",349,51,55,"Desolace",{5634,6052,13458})
add("st","Sunken Temple",109,54,59,"Swamp of Sorrows",{9030,13458})
add("brd","Blackrock Depths",230,56,60,"Blackrock Mountain",{13457,9030,5634})
add("lbrs","Lower Blackrock Spire",229,58,60,"Blackrock Mountain",{19440,9030,13457})
add("ubrs","Upper Blackrock Spire",229,60,60,"Blackrock Mountain",{13457,9030},10)
add("dm-east","Dire Maul: East",429,58,60,"Feralas",{13459,13457,9030})
add("dm-north","Dire Maul: North",429,60,60,"Feralas",{3829,15994,18258,9030,3387})
add("dm-west","Dire Maul: West",429,60,60,"Feralas",{13461,9030,3387})
add("scholo","Scholomance",289,60,60,"Western Plaguelands",{9030,13459,13456,3387})
add("strat-live","Stratholme: Living",329,60,60,"Eastern Plaguelands",{13457,9030,13459})
add("strat-dead","Stratholme: Undead",329,60,60,"Eastern Plaguelands",{13459,9030,19440,13456})

-- Short, instance-specific reasons to carry each item. These replace the generic
-- effect in the packing row; the full game tooltip is still available on hover.
D.uses={
    rfc={
        [2459]="General retreat through cleared rooms; no specific mob counter.",
    },
    wc={
        [6452]="Deviate Viper - remove Localized Toxin after it lands (poison level 25 or lower).",
        [6453]="Deviate Viper - stronger Localized Toxin cleanse (poison level 35 or lower).",
        [5634]="Verdan the Everliving - use BEFORE Grasping Vines. Does not prevent the druids' Sleep.",
    },
    deadmines={
        [2459]="General retreat through cleared tunnels; does not counter Mr. Smite's stun.",
    },
    stockades={
        [5634]="Defias Convict - use BEFORE Backhand stuns. Does not prevent Dextren Ward's fear.",
        [6052]="Hamhock - absorb some Chain Lightning damage; keep spread out.",
    },
    bfd={
        [6453]="Aku'mai - cleanse poison after it lands; poison level cap 35.",
        [6052]="Aku'mai - poison damage buffer; leave the cloud. Does not cleanse poison.",
        [5634]="Lady Sarevess / Gelihast - use BEFORE Frost Nova or Net roots; not Kelris' Sleep.",
    },
    gnomer={
        [6049]="Thermaplugg's Walking Bombs - extra fire absorb; still kill bombs before they reach you.",
        [5634]="Mechanized Guardian - use BEFORE Electrified Net roots you.",
    },
    rfk={
        [6052]="Charlga Razorflank / Razorfen Geomancer - buffer lightning damage.",
        [5634]="Razorfen Totemic - use BEFORE Earthgrab Totem roots; destroy the totem.",
    },
    ["sm-graveyard"]={
        [6049]="Interrogator Vishas - absorb Immolate fire damage.",
        [6453]="Ironspine - poison cleanse after leaving Poison Cloud; poison level cap 35.",
        [9030]="Ironspine - curse/poison removal every 5 sec; leave Poison Cloud first.",
    },
    ["sm-library"]={
        [9030]="Arcanist Doan - use before Silence for periodic magic removal; ticks every 5 sec.",
    },
    ["sm-cathedral"]={
        [9030]="Scarlet Sorcerer - periodic Slow or Frostbolt snare removal; ticks every 5 sec.",
    },
    rfd={
        [6050]="Amnennar the Coldbringer / Frost Spectres - absorb some frost damage.",
        [9030]="Glutton - periodic disease removal after leaving Disease Cloud.",
    },
    uldaman={
        [6049]="Stonevault Geomancer / Shadowforge Flame Keeper - buffer fire spells.",
        [9030]="Shadowforge Darkcaster - remove Shadow Word: Pain on a 5-sec tick.",
    },
    zf={
        [9030]="Sandfury Witch Doctor - use before Hex for periodic curse removal; ticks every 5 sec.",
        [6050]="Gahz'rilla - absorb frost damage; does not stop the knockback.",
        [5634]="Antu'sul - use BEFORE Earthgrab Totem roots; destroy the totem.",
    },
    ["mara-purple"]={
        [9030]="Corruptor / Poison Sprite - periodic Corruption or poison removal.",
    },
    ["mara-orange"]={
        [6052]="Noxxion / Creeping Sludge - buffer poison damage; does not cleanse it.",
        [13458]="Noxxion / Creeping Sludge - stronger nature absorb; does not cleanse poison.",
        [19440]="Noxxion - cleanse Toxic Volley poison after it lands.",
        [9030]="Noxxion - Toxic Volley poison removal on a 5-sec tick.",
    },
    ["mara-inner"]={
        [5634]="Theradrim Guardian / Cavern Shambler - use BEFORE Knockdown stuns.",
        [6052]="Princess Theradras - buffer Dust Field damage; still move away from her.",
        [13458]="Princess Theradras - stronger Dust Field damage buffer; does not stop knockback.",
    },
    st={
        [9030]="Atal'ai Witch Doctor - use before Hex for periodic curse removal; ticks every 5 sec.",
        [13458]="Shade of Eranikus - absorb Acid Breath damage; does not prevent Deep Slumber.",
    },
    brd={
        [13457]="Fireguard / Shadowforge Flame Keeper - buffer fire damage before their pulls.",
        [9030]="Lord Incendius - periodic Curse of the Elemental Lord removal; ticks every 5 sec.",
        [5634]="Anvilrage Officer / Warden - use BEFORE Backhand stuns or Hooked Net roots.",
    },
    lbrs={
        [19440]="Mother Smolderweb - remove Mother's Milk poison after it lands.",
        [9030]="Mother Smolderweb - Mother's Milk removal on a 5-sec tick; not an instant cleanse.",
        [13457]="Firebrand Invoker - buffer fire spells and Blast Wave damage.",
    },
    ubrs={
        [13457]="General Drakkisath / Rookery Whelps - buffer Conflagration and fire damage.",
        [9030]="Pyroguard Emberseer - periodic Flame Buffet removal; ticks every 5 sec.",
    },
    ["dm-east"]={
        [13459]="Zevrim Thornhoof - use BEFORE Sacrifice; absorbs damage without freeing you.",
        [13457]="Wildspawn Imp - buffer fire spells during imp pulls.",
        [9030]="Alzzin the Wildshaper - periodic Enervate poison or Wither disease removal.",
    },
    ["dm-north"]={
        [3829]="Guard Slip'kik - tribute trap component, together with a Thorium Widget.",
        [15994]="Guard Slip'kik - repair the tribute trap, together with Frost Oil.",
        [18258]="Captain Kromcrush - planned tribute disguise; use before approaching him.",
        [9030]="Gordok Warlock - periodic Curse of Tongues removal.",
        [3387]="Gordok Reaver - emergency melee immunity; tank use can redirect attacks onto allies.",
    },
    ["dm-west"]={
        [13461]="Arcane Aberration - buffer Arcane Explosion damage around the pylons.",
        [9030]="Magister Kalendris - periodic Shadow Word: Pain removal; not a mind-control escape.",
        [3387]="Prince Tortheldrin - emergency melee immunity; tank use can redirect attacks onto allies.",
    },
    scholo={
        [9030]="Lord Alexei Barov - Veil of Shadow removal on a 5-sec tick; keep assigned dispels.",
        [13459]="Lord Alexei Barov - buffer his shadow aura damage.",
        [13456]="Ras Frostwhisper - buffer frost damage; still spread out.",
        [3387]="Darkmaster Gandling's skeleton rooms - brief melee immunity if teleported alone.",
    },
    ["strat-live"]={
        [13457]="Crimson Battle Mage - buffer fire spells before caster pulls.",
        [9030]="Balnazzar - periodic Shadow Word: Pain removal.",
        [13459]="Balnazzar - buffer shadow spells; does not stop mind control.",
    },
    ["strat-dead"]={
        [13459]="Baron Rivendare - buffer Unholy Aura damage.",
        [9030]="Baroness Anastari - periodic curse removal; does not let you cast while possessed.",
        [19440]="Venom Belcher - remove Venom Spit poison after it lands.",
        [13456]="Maleki the Pallid - buffer frost spells; does not prevent Ice Tomb.",
    },
}

-- Raid entries are added by Data/InstancesRaids.lua.
D.AddRaid=function(id,name,map,players,zone,pack)
    add(id,name,map,60,60,zone,pack,players,"raids")
end
