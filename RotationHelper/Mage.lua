-- Mage policy only: spell definitions and conditions over the shared snapshot.
-- No events, game API calls, action buttons, timers or persistence belong here.
local _,A=...
local M={name="Mage",pauseAuras={11958},spells={
    frostbolt={root=116,enemy=true,school=16}, fireball={root=133,enemy=true,school=4},
    fireblast={root=2136,enemy=true,school=4}, scorch={root=2948,enemy=true,school=4},
    pyroblast={root=11366,enemy=true,school=4}, missiles={root=5143,enemy=true,school=64},
    nova={root=122,enemy=true,near=true,lowest=true,school=16},
    counterspell={root=2139,enemy=true,school=64},
    intellect={root=1459}, frostarmor={root=168}, icearmor={root=7302}, magearmor={root=6117},
    barrier={root=11426}, manashield={root=1463}, iceblock={root=11958}, coldsnap={root=12472},
    decurse={root=475}, evocation={root=12051}, arcanePower={root=12042}, combustion={root=11129},
    shoot={root=5019,enemy=true,wand=true},
    gem={items={5514,5513,8007,8008}},
    conjureGem={ranks={759,3552,10053,10054},creates={5514,5513,8007,8008}},
},auras={
    slow={116,205,837,7322,8406,8407,8408,10179,10180,10181,25304},
    frozen={122,865,6131,10230,12494,33395},
    barrier={11426,13031,13032,13033},manashield={1463,8494,8495,10191,10192,10193},
    iceblock={11958},hypothermia={41425},combustion={11129},
    armor={168,7300,7301,7302,7320,10219,10220,6117,22782,22783},
    intellect={1459,1460,1461,10156,10157,23028,3160,11390,17535,8096,8097,8098,12176},
    scorch={22959},clearcasting={12536},presence={12043},
},strengths={intellect={[1459]=2,[1460]=7,[1461]=15,[10156]=22,[10157]=31,[23028]=31,
    [3160]=8,[11390]=25,[17535]=25,[8096]=4,[8097]=8,[8098]=12,[12176]=16}}}
A.RotationHelper.classes.MAGE=M

local function combat(c) return c.hostile and not c.recovering and (not c.grouped or c.targetCombat) end
local function fire(c)
    return c.treePoints[2]>c.treePoints[3]
end
local function refresh(c,aura) return not c.combat and not c.recovering and c:remaining(aura)<=300 end
local function rule(spell,category,group,when) return {spell=spell,category=category,group=group,when=when} end
M.rules={
    rule("counterspell","defensive","interrupt",function(c)
        return combat(c) and c.targetCast and c.targetCast.interruptible and c.targetCast.remaining>0.2 and "Interrupt the target's cast"
    end),
    rule("iceblock","defensive","survival",function(c)
        return c.combat and c.health<0.2 and c.attacked and c:remaining("hypothermia")==0 and "Emergency immunity; plan your escape"
    end),
    rule("barrier","defensive","shield",function(c)
        return c.combat and c:remaining("barrier")==0 and "Absorb damage before continuing"
    end),
    rule("manashield","defensive","shield",function(c)
        return c.combat and c.attacked and c.health<0.35 and c.mana>0.35 and c:remaining("barrier")==0
            and c:remaining("manashield")==0 and "Emergency shield; consumes mana"
    end),
    rule("nova","defensive","control",function(c)
        return c.combat and c.targetAttacking and not c.nearbyCC and c:remaining("frozen","target")==0 and "Root the close attacker, then create distance"
    end),
    rule("decurse","defensive","dispel",function(c) return c.cursed and "Remove your curse" end),
    rule("coldsnap","defensive","survival",function(c)
        return c.combat and c.attacked and c.health<0.3
            and (c.spells.iceblock.known and c.spells.iceblock.cooldown>2 or c.spells.barrier.known and c.spells.barrier.cooldown>2)
            and "Reset unavailable Frost survival cooldowns"
    end),
    rule("gem","offensive","mana",function(c) return c.combat and c.mana<0.45 and "Restore mana without a cast" end),
    rule("arcanePower","offensive","damage",function(c)
        return combat(c) and c.targetCombat and c.targetHealth>0.7 and c.mana>0.65 and c.tough and not c.attacked and "Burst on an engaged, durable target"
    end),
    rule("combustion","offensive","damage",function(c)
        return fire(c) and combat(c) and c.targetHealth>0.7 and c:remaining("combustion")==0 and "Improve your Fire critical strikes"
    end),
    rule("shoot","main",nil,function(c)
        return combat(c) and (c.mana<0.15 or not c.tough and c.targetHealth<0.12) and c:remaining("clearcasting")==0 and "Conserve mana with your wand"
    end),
    rule("pyroblast","main",nil,function(c)
        return fire(c) and combat(c) and not c.combat and not c.targetCombat and not c.cast and "Open with Pyroblast"
    end),
    rule("scorch","main",nil,function(c)
        local pendingStack=c.casting=="scorch" and (c.talents.improvedScorch or 0)>=3
        return fire(c) and combat(c) and c.tough and (c.talents.improvedScorch or 0)>0
            and (c:stacks("scorch","target")+(pendingStack and 1 or 0)<5
                or c:remaining("scorch","target")<5 and not pendingStack) and "Build or refresh Fire Vulnerability on a durable target"
    end),
    rule("fireblast","main",nil,function(c)
        return combat(c) and not c.tough and c.targetHealth<0.15 and c.mana>0.25 and "Finish a low-health target"
    end),
    rule("fireball","main",nil,function(c)
        return combat(c) and (fire(c) and (c.grouped or c:remaining("slow","target")>0 or c.casting=="frostbolt")
            or not c.spells.frostbolt.known or c.immune.frostbolt) and "Use your Fire attack"
    end),
    rule("frostbolt","main",nil,function(c) return combat(c) and "Damage and slow your target" end),
    rule("fireball","main",nil,function(c) return combat(c) and "Use your available Fire attack" end),
    rule("missiles","main",nil,function(c) return combat(c) and "Arcane fallback when other schools are unavailable" end),
    rule("shoot","main",nil,function(c) return combat(c) and "Wand while conserving mana" end),
    rule("barrier","preparation","shield",function(c)
        return not c.combat and not c.recovering and c:remaining("barrier")==0 and "Prepare Ice Barrier before pulling"
    end),
    rule("intellect","preparation","intellect",function(c)
        return refresh(c,"intellect") and c:strength("intellect")<=(M.strengths.intellect[c.spells.intellect.id] or 0)
            and "Refresh Arcane Intellect"
    end),
    rule("magearmor","preparation","armor",function(c) return c.grouped and refresh(c,"armor") and "Maintain mana regeneration in your group" end),
    rule("icearmor","preparation","armor",function(c) return refresh(c,"armor") and "Maintain physical protection while leveling" end),
    rule("frostarmor","preparation","armor",function(c) return refresh(c,"armor") and "Maintain physical protection while leveling" end),
    rule("magearmor","preparation","armor",function(c) return refresh(c,"armor") and "Maintain your available armor buff" end),
    rule("evocation","preparation","recovery",function(c)
        return not c.combat and not c.hostile and not c.recovering and not c.cast and c.mana<0.25 and "Recover mana in a safe place"
    end),
    rule("conjureGem","preparation","gem",function(c)
        return not c.combat and not c.recovering and c.spells.conjureGem.createdCount==0 and "Prepare a mana gem before combat"
    end),
}
