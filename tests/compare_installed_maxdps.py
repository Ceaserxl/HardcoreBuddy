"""Read-only audit of installed MaxDps Classic behavior; never loaded by WoW.

Uses the installed source in an isolated Lua runtime with synthetic game APIs.
This verifies source paths, not live client compatibility or measured DPS.
Run with Python + lupa; --output writes the optional audit artifact.
"""
from pathlib import Path
import argparse
import hashlib
import json

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--addons-root", type=Path, default=ROOT.parent)
parser.add_argument("--output", type=Path)
args = parser.parse_args()
sources = {}


def read(relative):
    path = args.addons_root / relative
    data = path.read_bytes()
    sources[relative] = hashlib.sha256(data).hexdigest()
    return data.decode("utf-8-sig")


def method(source, start, following):
    return source[source.index(start):source.index(following, source.index(start))]


lua = LuaRuntime(unpack_returned_tuples=True)
inventory = []
compile_lua = lua.eval("function(source,name) local fn,err=loadstring(source,name); return fn~=nil,err end")
for folder in sorted(args.addons_root.glob("MaxDps*")):
    toc = folder / (folder.name + ".toc")
    if not toc.is_file():
        continue
    lines = read(toc.relative_to(args.addons_root).as_posix()).splitlines()
    version = next((line.split(":", 1)[1].strip() for line in lines if line.startswith("## Version:")), "unknown")
    files = []
    for line in lines:
        line = line.strip().replace("\\", "/")
        if not line.lower().endswith(".lua") or line.lower().startswith("libs/"):
            continue
        relative = folder.name + "/" + line
        valid, error = compile_lua(read(relative), "@" + relative)
        if not valid:
            raise ValueError(error)
        files.append(relative)
    inventory.append({"addon": folder.name, "version": version, "syntax_checked_files": files})
lua.execute(r'''
local names = {
 [116]="Frostbolt",[10181]="Frostbolt",[133]="Fireball",[25306]="Fireball",
 [2136]="Fire Blast",[10199]="Fire Blast",[2948]="Scorch",[10207]="Scorch",
 [11129]="Combustion",[12526]="Pyroblast",[10216]="Flamestrike",
 [10161]="Cone of Cold",[10202]="Arcane Explosion",[10187]="Blizzard",
 [12051]="Evocation",[12042]="Arcane Power",[12043]="Presence of Mind",
 [5143]="Arcane Missiles",[16770]="Improved Arcane Missiles",
 [12873]="Improved Scorch",[22959]="Fire Vulnerability",[12848]="Ignite",
 [12654]="Ignite",[61304]="Global Cooldown",
}
function reset()
 X={now=100,power=1000,maxPower=1000,health=1000,targetHealth=1000,targets=1,
    range=25,known={},cd={},gcdStart=0,gcdDuration=0,apiUsable=true,passive={}}
 MaxDps.SpellTable={}; MaxDps.ItemSpells={}; MaxDps.ActiveDots={}
 MaxDps.PlayerTalents={}
 MaxDps.PlayerAuras=setmetatable({}, {__index=function() return {up=false,refreshable=true,count=0} end})
 MaxDps.TargetAuras=setmetatable({}, {__index=function() return {up=false,refreshable=true,count=0} end})
 MaxDps.FrameData={cooldown=setmetatable({}, {__index=function(_,id) return MaxDps:CooldownConsolidated(id,MaxDps.FrameData.timeShift) end}),
  buff=MaxDps.PlayerAuras,debuff=MaxDps.TargetAuras,talents=MaxDps.PlayerTalents,timeShift=0,gcd=1.5}
end
MaxDps={Colors={Error=""}}
function MaxDps:NewModule() return {} end
function MaxDps:Print() end
function MaxDps:IsClassicWow() return true end
function MaxDps:IsRetailWow() return false end
function MaxDps:IsMistsWow() return false end
function MaxDps:IsCataWow() return false end
function MaxDps:IsTBCWow() return false end
function MaxDps:SmartAoe() return X.targets end
function GetTime() return X.now end
function UnitPower() return X.power end
function UnitPowerMax() return X.maxPower end
function UnitHealth(unit) return unit=="player" and X.health or X.targetHealth end
function UnitHealthMax() return 1000 end
function UnitSpellHaste() return 0 end
function GetCritChance() return 0 end
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return "Mage",nil,0,#X.known end
function GetSpellBookItemInfo(i) return "SPELL",X.known[i] end
function GetSpellBaseCooldown() return 0 end
C_Spell={
 GetSpellName=function(id) return names[id] end,
 GetSpellInfo=function(id) return {name=names[id],spellID=id,castTime=3000} end,
 IsSpellPassive=function(id) return X.passive[id] or false end,
 IsSpellUsable=function() return X.apiUsable end,
 GetSpellCharges=function() return nil end,
 GetSpellCooldown=function(id)
  if id==61304 then return {startTime=X.gcdStart,duration=X.gcdDuration,isEnabled=true} end
  local cd=X.cd[id] or {}
  return {startTime=cd.start or 0,duration=cd.duration or 0,isEnabled=cd.enabled~=false}
 end,
 RequestLoadSpellData=function() end,
}
C_UnitAuras={}
Enum={PowerType=setmetatable({Mana=0},{__index=function() return 1 end})}
function LibStub() return {GetRange=function() return X.range,X.range end} end
local GetSpellTabInfo=GetSpellTabInfo
local GetSpellBookItemInfo=GetSpellBookItemInfo
''')
helper = read("MaxDps/Helper.lua")
lua.execute(method(helper, "function MaxDps:CheckSpellUsable(", "function MaxDps:GetSpellCost("))
lua.execute(method(helper, "function MaxDps:CooldownConsolidated(", "-- @deprecated"))
lua.execute(method(helper, "function MaxDps:FindADAuraData(", "function MaxDps:FindBuffAuraData("))
lua.execute("reset()")
addon = lua.table()
lua.execute(read("MaxDps_Mage/Main.lua"), "MaxDps_Mage", addon)
for spec in ("Arcane", "Fire", "Frost"):
    lua.execute(read(f"MaxDps_Mage/Specialization/Classic/{spec}.lua"), "MaxDps_Mage", addon)
lua.globals().Mage = addon.Mage
buttons = read("MaxDps/Buttons.lua")
lua.execute("FindBaseSpellByID=function(id) return id end; FindSpellOverrideByID=FindBaseSpellByID; IsMounted=function() return false end")
lua.execute("local GetSpellName=C_Spell.GetSpellName; local GetSpellInfo=C_Spell.GetSpellInfo;\n" +
            method(buttons, "function MaxDps:GlowSpell(", "function MaxDps:GlowNextSpell("))
core = read("MaxDps/Core.lua")
lua.execute(method(core, "function MaxDps:InvokeNextSpell()", "function MaxDps:InitRotations("))

checks = lua.execute(r'''
local out={}
local function check(name,setup,expression,expected)
 reset(); if setup then setup() end
 local value=expression()
 out[#out+1]={name=name,expected=tostring(expected),actual=tostring(value),matched=value==expected}
end
check("Frost only knows rank one; returns hardcoded higher rank for name matching",
 function() X.known={116} end,function() return Mage:Frost() end,10181)
check("Classic usability ignores API unusable result and zero mana",
 function() X.known={116};X.power=0;X.apiUsable=false end,function() return Mage:Frost() end,10181)
check("Frost single target does not gate target range",
 function() X.known={116};X.range=80 end,function() return Mage:Frost() end,10181)
check("Frost single target does not respond to critical player health",
 function() X.known={116};X.health=10 end,function() return Mage:Frost() end,10181)
check("Fire requests Scorch with no Improved Scorch talent",
 function() X.known={2948,133} end,function() return Mage:Fire() end,10207)
check("Five Fire Vulnerability stacks still request Scorch under talent-ID lookup",
 function() X.known={2948,133};MaxDps.ActiveDots.enemy={{name="Fire Vulnerability",applications=5,expirationTime=125,duration=30}} end,
 function() return Mage:Fire() end,10207)
check("Frost AoE prioritizes Flamestrike even while its effect is healthy",
 function() X.targets=2;X.known={116,10216,10161,10202};X.range=5
  MaxDps.ActiveDots.enemy={{name="Flamestrike",applications=1,expirationTime=108,duration=8}}
 end,function() return Mage:Frost() end,10216)
check("Two-target branch can return nothing despite a known ranged Frostbolt",
 function() X.targets=2;X.known={116,10202};X.range=25 end,function() return Mage:Frost() end,nil)
check("Cooldown ignores a three-second cast look-ahead",
 function() X.cd[2136]={start=100,duration=2} end,
 function() return MaxDps:CooldownConsolidated(2136,3).ready end,false)
check("Cooldown compares against full GCD duration rather than remaining GCD",
 function() X.now=101.4;X.gcdStart=100;X.gcdDuration=1.5;X.cd[2136]={start=100,duration=2.7} end,
 function() return MaxDps:CooldownConsolidated(2136,0.1).ready end,true)
check("Cooldown accepts the final half second without a running GCD",
 function() X.cd[2136]={start=99.6,duration=0.8} end,
 function() return MaxDps:CooldownConsolidated(2136,0).ready end,true)
check("Classic cooldown ignores disabled flag when timing reports zero",
 function() X.cd[2136]={enabled=false} end,
 function() return MaxDps:CooldownConsolidated(2136,0).ready end,true)
check("Arcane prioritizes Evocation at 35 percent mana even with low health",
 function() X.known={12051,116};X.power=350;X.health=100 end,function() return Mage:Arcane() end,12051)
check("Classic spell-name glow lights multiple ranks",
 function()
  MaxDps.Spells={[116]={{rank=1}},[10181]={{rank=10}}};MaxDps.SpellsGlowing={};X.lit={}
  MaxDps.Glow=function(_,button) X.lit[button.rank]=true end
 end,function() MaxDps:GlowSpell(10181);return X.lit[1] and X.lit[10] end,true)
check("Repeated core invocation replaces Main while the same cast is active",
 function()
  X.known={11129,2948};X.cd[11129]={start=100,duration=2}
  MaxDps.FrameData.currentSpell=133;MaxDps.FrameData.timeShift=3
  MaxDps.db={global={cdOnlyMode=false,spellFrame={enabled=false}}}
  MaxDps.PrepareFrameData=function() end;MaxDps.UpdateAuraData=function() end
  MaxDps.GlowConsumables=function() end;MaxDps.GlowNextSpell=function() end
  MaxDps.GlowClear=function() end;MaxDps.NextSpell=Mage.Fire;MaxDps.Spell=nil
 end,function()
  MaxDps:InvokeNextSpell();local before=MaxDps.Spell
  X.now=101.6;MaxDps.FrameData.timeShift=1.4
  MaxDps:InvokeNextSpell();return tostring(before).." -> "..tostring(MaxDps.Spell)
 end,"10207 -> 11129")
return out
''')
rows = [dict(checks[i].items()) for i in range(1, len(checks) + 1)]
report = {"scope": "Installed source with synthetic APIs; not live WoW or DPS benchmarking",
          "checks": rows, "source_sha256": sources,
          "inventory": inventory,
          "matched": sum(row["matched"] for row in rows), "count": len(rows)}
for row in rows:
    print(f"{'MATCH' if row['matched'] else 'MISMATCH'}: {row['name']}: {row['actual']}")
if args.output:
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(f"{report['matched']}/{report['count']} source-behavior expectations reproduced")
print(f"{sum(len(addon['syntax_checked_files']) for addon in inventory)} TOC-loaded non-library Lua files syntax checked across {len(inventory)} addons")
raise SystemExit(report["matched"] != report["count"])
