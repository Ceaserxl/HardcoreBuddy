-- Classic Era raid levels and packing lists.
local _, A = ...
local D=A.Data.Instances
local add=D.AddRaid

add("mc","Molten Core",409,40,"Blackrock Mountain",{13457,9030})
add("ony","Onyxia's Lair",249,40,"Dustwallow Marsh",{13457})
add("bwl","Blackwing Lair",469,40,"Blackrock Mountain",{15138,19183,13457,9030,19440})
add("zg","Zul'Gurub",309,20,"Stranglethorn Vale",{13458,13457,19440,9030})
add("aq20","Ruins of Ahn'Qiraj",509,20,"Silithus",{13458,19440,9030})
add("aq40","Temple of Ahn'Qiraj",531,40,"Silithus",{13458,19440,9030,3829,13459})
add("naxx","Naxxramas",533,40,"Eastern Plaguelands",{13456,13459,13458,19440,9030})

D.AddRaid=nil

D.uses.mc={
    [13457]="Baron Geddon / Firelords - buffer fire damage; still move away for Inferno or Living Bomb.",
    [9030]="Lucifron / Gehennas - backup curse removal every 5 sec; keep assigned dispels.",
}
D.uses.ony={
    [13457]="Onyxia / Onyxian Warders - pre-pull fire absorb; still avoid Deep Breath.",
}
D.uses.bwl={
    [15138]="Firemaw, Ebonroc, Flamegor & Nefarian - EQUIP before Shadow Flame; initial hit still hurts.",
    [19183]="Chromaggus - remove Brood Affliction: Bronze after it lands.",
    [13457]="Firemaw - buffer Flame Buffet damage; still reset stacks behind cover.",
    [9030]="Chromaggus - periodic removable affliction cleanse; Bronze needs Hourglass Sand.",
    [19440]="Chromaggus - remove Brood Affliction: Green (poison), not the other colors.",
}
D.uses.zg={
    [13458]="High Priest Venoxis - buffer poison damage; still leave Poison Cloud.",
    [13457]="Gurubashi Bat Rider - fire absorb only; move away before the explosion.",
    [19440]="High Priest Venoxis - poison cleanse. Keep the Son's poison during Hakkar's siphon plan.",
    [9030]="High Priest Venoxis - poison backup. Avoid removing Hakkar's poison or Jin'do's useful curse.",
}
D.uses.aq20={
    [13458]="Ayamiss the Hunter - buffer Poison Stinger damage.",
    [19440]="Ayamiss the Hunter - remove Poison Stinger after it lands.",
    [9030]="Ayamiss the Hunter - Poison Stinger removal on a 5-sec tick.",
}
D.uses.aq40={
    [13458]="Princess Huhuran / Viscidus - use before poison volleys as assigned.",
    [19440]="Viscidus - remove Poison Bolt Volley poison after it lands.",
    [9030]="Viscidus - periodic poison removal; follow the raid's cleanse plan.",
    [3829]="Viscidus - weapon frost procs for the assigned freeze plan; procs are not guaranteed.",
    [13459]="Emperor Vek'lor - buffer Shadow Bolt damage for assigned tanks.",
}
D.uses.naxx={
    [13456]="Sapphiron / Kel'Thuzad - frost damage buffer; still use cover and Frost Blast spacing.",
    [13459]="Loatheb - time the absorb for Inevitable Doom with the raid's calls.",
    [13458]="Maexxna - poison damage buffer; does not prevent Web Spray.",
    [19440]="Maexxna - Necrotic Poison cleanse. Do not cleanse Grobbulus' Injection in the raid.",
    [9030]="Noth / Heigan - curse or disease backup every 5 sec. Do not auto-cleanse Grobbulus' Injection.",
}
