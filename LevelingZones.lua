local _,A=...
local Z={}; A.LevelingZones=Z

function Z.Build(context,state)
    local blocks={}
    local faction=context.faction
    if faction~="Alliance" and faction~="Horde" then faction=nil end
    local level=context.level
    if faction=="Alliance" or faction=="Horde" then
        for _,entry in ipairs(A.Data.LevelingZones) do
            local band=entry[faction] or entry.both
            local zone=A.Data.MapZones[entry.map]
            local name=zone.name..(entry.part and (" - "..entry.part) or "")
            if band and (state.showAllZones or level>=band[1]-3 and level<=band[2]+3)
                and name:lower():find((state.query or ""):lower(),1,true) then
                local status=level<band[1] and "Upcoming" or level>band[2] and "Finishing up" or "In range"
                blocks[#blocks+1]={title=name,body="Recommended levels "..band[1].."-"..band[2].." | "..status,
                    action={kind="mapAdvisor",command="open",id=entry.map},low=band[1],high=band[2],map=entry.map}
            end
        end
    end
    table.sort(blocks,function(a,b) if a.low~=b.low then return a.low<b.low end; return a.title<b.title end)
    local total=#blocks
    if total==0 then blocks[1]={title=faction and "No matching zones" or "Faction unavailable",
        body=faction and "Try Show all or clear your search." or "Zone recommendations will appear when your character's faction is available."} end
    local note=(context.mode=="preview" and "Planned level " or "Your level ")..level.." | "..(faction or "Unknown faction")
        ..(state.showAllZones and " | All levels" or " | Ranges within 3 levels")
        .."\nClick a zone to open its map. For Hardcore, favor green quests and check individual enemy levels."
    return {view="training",context=context,cards={{title="Recommended leveling zones",note=note,blocks=blocks}},
        continuous=true,page=1,pages=1,total=total,searchable=true,levelFilter=true}
end
