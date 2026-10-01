-- Instance level ranges and compact packing lists.
local _, A = ...
local I={byId={},byMap={}}; A.Instances=I
local D=A.Data.Instances
for _,g in ipairs(D.guides) do
    I.byId[g.id]=g
    I.byMap[g.map]=I.byMap[g.map] or {}
    I.byMap[g.map][#I.byMap[g.map]+1]=g
end
local function row(title,body,tone,action,meta)
    return {title=title,body=body,guideTone=tone or "plain",action=action,meta=meta}
end
local function card(title,note,blocks) return {title=title,note=note,blocks=blocks or {}} end
local function levels(g)
    return g.low==g.high and "Level "..g.low or "Levels "..g.low.."-"..g.high
end
local function label(g) return levels(g).."  |  "..g.players.." players  |  "..g.zone end
local function columns(rows)
    local blocks={}
    for n=1,#rows,2 do
        local pair={{rows[n]}}
        if rows[n+1] then pair[2]={rows[n+1]} end
        blocks[#blocks+1]={columns=pair}
    end
    return blocks
end
function I.Current()
    if type(IsInInstance)~="function" or type(GetInstanceInfo)~="function" then return end
    local inside=IsInInstance()
    if not inside then return end
    local ok,name,kind,_,_,_,_,_,map=pcall(GetInstanceInfo)
    if not ok or (kind~="party" and kind~="raid") then return end
    local guides=I.byMap[map] or {}
    return {name=name or "Unknown instance",map=map,guides=guides,
        view=guides[1] and guides[1].kind or (kind=="raid" and "raids" or "dungeons")}
end
function I.Navigation()
    return {"All","Dungeons","Raids"}
end
local function toolRow(id,context,g)
    local t=D.tools[id]
    local requirement=t.skill or (t.level>1 and "Level "..t.level or nil)
    local inv=context.inventory
    local count=inv and inv.available and (inv.counts[id] or 0) or nil
    local stock=count and ((context.mode=="preview" and "Live bags: " or "In bags: ")..count) or "Bag count unavailable"
    if id==15138 and context.mode~="preview" and type(GetInventoryItemID)=="function" and GetInventoryItemID("player",15)==id then
        stock="Equipped"
    end
    local use=D.uses[g.id] and D.uses[g.id][id]
    local description=use or t.description
    local r=row(t.name,description,"tool",nil,(requirement and (requirement.."  |  ") or "")..stock)
    r.itemId=id; r.icon=t.icon
    if context.level<t.level then r.meta="|cfff08c70Requires level "..t.level.."|r  |  "..stock end
    return r
end
local function packingList(g,context)
    local blocks={{columns={
        {row("Potions",nil,"link",{view="supplies",filter="Potions"})},
        {row("Food & drink",nil,"link",{view="supplies",filter="Food & drink"})},
        {row("Bandages & tools",nil,"link",{view="supplies",filter="Emergency"})},
        {row("Class supplies",nil,"link",{view="supplies",filter="Class"})},
    }}}
    local note=label(g).."\nSuggested full-run levels. Potions share a cooldown."
    if context.level<g.low then note=note.."\n|cfff08c70Above your "..(context.mode=="preview" and "planned " or "").."level|r" end
    if #g.pack>0 then
        local items={}
        for _,id in ipairs(g.pack) do items[#items+1]=toolRow(id,context,g) end
        for _,block in ipairs(columns(items)) do blocks[#blocks+1]=block end
    end
    return {card(g.name,note,blocks)}
end
local function matches(g,query)
    local hay=(g.name.." "..g.zone):lower()
    for word in (query or ""):lower():gmatch("%S+") do if not hay:find(word,1,true) then return false end end
    return true
end
function I.Build(context,state)
    local result={context=context,view="instances",cards={},continuous=true,page=1,pages=1,total=0,instanceGuide=true}
    local g=I.byId[state.instance]
    if g then
        result.guide=g
        result.cards=packingList(g,context)
        return result
    end
    local filter=state.filter or "All"
    local valid=false
    for _,name in ipairs(I.Navigation(state)) do if filter==name then valid=true end end
    if not valid then filter="All" end
    result.searchable=true
    result.levelFilter=not state.currentMap and not state.unknownInstance
    local list={}
    local hidden=0
    for _,entry in ipairs(D.guides) do
        local kind=filter=="All" or (filter=="Dungeons" and entry.kind=="dungeons") or (filter=="Raids" and entry.kind=="raids")
        if kind and (not state.currentMap or entry.map==state.currentMap)
            and not state.unknownInstance and matches(entry,state.query) then
            if state.showAllInstances or state.currentMap or (context.level>=entry.low-3 and context.level<=entry.high+3) then
                list[#list+1]=entry
            else hidden=hidden+1 end
        end
    end
    local title=state.currentMap and (state.currentName or "Current instance") or (filter=="All" and "Dungeons & Raids" or filter)
    local note=state.currentMap and "Choose your wing to see levels and items to bring."
        or (state.showAllInstances and "All levels. " or (context.mode=="preview" and "Planned level: " or "Your level: ")..context.level..". Showing ranges within 3 levels. ")
            .."Select an instance for items to bring.\nRanges are suggested full-run levels."
    if hidden>0 then note=note.." "..hidden.." hidden by level; Show all to browse them." end
    local tiles={}
    for _,entry in ipairs(list) do
        tiles[#tiles+1]=row(entry.name,levels(entry),"link",{kind="instance",id=entry.id},(entry.kind=="raids" and "Raid" or "Dungeon").."  |  "..entry.players.." players  |  "..entry.zone)
    end
    local blocks=columns(tiles)
    if #list==0 then
        blocks[1]=row(state.unknownInstance and "No Classic Era entry for this instance" or "No matching instances",
            state.unknownInstance and "Choose All, Dungeons or Raids to browse." or "Try Show all, choose another category, or change your search.","plain")
    end
    result.cards={card(title,note,blocks)}; result.total=#list
    return result
end
