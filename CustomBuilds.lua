-- Account-wide talent paths and their complete stat-weight bundles.
local _,A=...
local B={limit=100,maxText=4096}; A.CustomBuilds=B
local function copy(t)
    if type(t)~="table" then return t end
    local out={}; for k,v in pairs(t) do out[k]=copy(v) end; return out
end
B.Copy=copy
local function library()
    if not A.db then return {} end
    A.db.customBuilds=A.db.customBuilds or {}; return A.db.customBuilds
end
function B:Get(id,class)
    local b=library()[id]
    if b and (not class or b.class==class) then return b end
end
function B:List(class)
    local out={}
    for _,b in pairs(library()) do if b.class==class then out[#out+1]=b end end
    table.sort(out,function(a,b) if a.name==b.name then return a.id<b.id end; return a.name<b.name end)
    return out
end
function B:Nodes(class)
    local out={}; for key in pairs(A.Data.AdvisorTalents[class] or {}) do out[#out+1]=key end
    table.sort(out); return out
end
function B:CanAdd(build,key)
    local nodes=A.Data.AdvisorTalents[build.class]; local node=nodes and nodes[key]
    if not node or #build.steps>=51 then return false end
    local ranks,points={},0
    for _,k in ipairs(build.steps) do
        if not nodes[k] then return false end
        ranks[k]=(ranks[k] or 0)+1
        if nodes[k].tree==node.tree then points=points+1 end
    end
    return (ranks[key] or 0)<node.maxRank and points>=(node.tier-1)*5
        and (not node.prerequisite or (ranks[node.prerequisite] or 0)==nodes[node.prerequisite].maxRank)
end
function B:Validate(build,allowEmpty)
    if type(build)~="table" or not A.Data.AdvisorTalents[build.class] then return nil,"Choose a Classic class." end
    if type(build.name)~="string" or #build.name<1 or #build.name>60 or build.name:find("[%c|]") or not build.name:find("%S") then
        return nil,"Use a build name of 1-60 characters, without control characters or |."
    end
    if type(build.profile)~="number" or build.profile~=math.floor(build.profile) or not A.Data.AdvisorGear[build.class][build.profile] then return nil,"Choose a valid scoring specialization." end
    if type(build.steps)~="table" or #build.steps>51 or (not allowEmpty and #build.steps==0) then return nil,"Choose between 1 and 51 talent points." end
    local trial={class=build.class,steps={}}
    for i,key in ipairs(build.steps) do
        if type(key)~="string" or not self:CanAdd(trial,key) then return nil,"Illegal talent at point "..i..". Check ranks, tiers and prerequisites." end
        trial.steps[i]=key
    end
    if type(build.weights)~="table" then return nil,"This build needs stat weights." end
    local weights={}
    for _,field in ipairs(A.GearAdvisor.WeightFields) do
        local v=build.weights[field[1]]
        if type(v)~="number" or v~=v or v<0 or v>1000000 then return nil,"Every stat weight must be between 0 and 1,000,000." end
        weights[field[1]]=v
    end
    return {name=build.name,class=build.class,profile=build.profile,steps=copy(build.steps),weights=weights,
        minLevel=10,maxLevel=60,custom=true}
end
function B:Draft(class,source)
    source=source or A.TalentAdvisor:Build(class,60)
    local p=A.GearAdvisor.Profile(class,60,nil,source.profile)
    p.buildID=source.id; p=A.GearAdvisor:ApplyWeights(p)
    return {name=source.name.." Copy",class=class,profile=source.profile,steps=copy(source.steps),weights=copy(p.weights)}
end
function B:Changed()
    A.TalentAdvisor.applying=nil
    A.GearAdvisor:WeightsChanged()
    if A.TalentRanks then A.TalentRanks:Refresh() end
    A.needsRefresh=true
end
function B:Save(draft,id)
    local b,err=self:Validate(draft); if not b then return nil,err end
    local saved=library()
    if id and (not saved[id] or saved[id].class~=b.class) then return nil,"The custom build no longer exists." end
    if not id then
        local count=0; for _ in pairs(saved) do count=count+1 end
        if count>=self.limit then return nil,"Custom build library is full (100 builds)." end
        A.db.customBuildSerial=(tonumber(A.db.customBuildSerial) or 0)+1
        id="custom:"..A.db.customBuildSerial
        while saved[id] do A.db.customBuildSerial=A.db.customBuildSerial+1; id="custom:"..A.db.customBuildSerial end
    end
    b.id=id; b.revision=(saved[id] and saved[id].revision or 0)+1; saved[id]=b
    local selected=A.characterDB and A.characterDB.advisors and A.characterDB.advisors.builds
    if selected and selected[b.class]==id then A.characterDB.autoApplyTalents=false end
    self:Changed(); return b
end
function B:Delete(id)
    if not library()[id] then return false end
    library()[id]=nil
    local s=A.characterDB and A.characterDB.advisors
    if s and s.builds then for class,chosen in pairs(s.builds) do if chosen==id then s.builds[class]=nil; A.characterDB.autoApplyTalents=false end end end
    self:Changed(); return true
end
function B:FromCurrent(class,profile)
    local live,err=A.TalentAdvisor:ReadCurrent(class,UnitLevel("player"))
    if not live then return nil,err end
    local draft=self:Draft(class,{name="Current Talents",profile=profile,steps={}})
    local keys=self:Nodes(class); local ranks={}
    while #draft.steps<live.points do
        local added=false
        for _,key in ipairs(keys) do
            if (ranks[key] or 0)<(live.ranks[key] or 0) and self:CanAdd(draft,key) then
                draft.steps[#draft.steps+1]=key; ranks[key]=(ranks[key] or 0)+1; added=true; break
            end
        end
        if not added then return nil,"Could not form a legal path from your current talents." end
    end
    draft.name="Current Talents"; return draft
end
local function checksum(s)
    local a,b=1,0; for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
    return tostring(b*65536+a)
end
local function split(s,sep)
    local out={}; for value in (s..sep):gmatch("(.-)"..sep) do out[#out+1]=value end; return out
end
function B:Export(build)
    local b,err=self:Validate(build); if not b then return nil,err end
    local keys=self:Nodes(b.class); local indices={}; for i,key in ipairs(keys) do indices[key]=i end
    local steps,weights={},{}
    for i,key in ipairs(b.steps) do steps[i]=indices[key] end
    for i,field in ipairs(A.GearAdvisor.WeightFields) do weights[i]=string.format("%.17g",b.weights[field[1]]) end
    local name=b.name:gsub(".",function(c) return string.format("%02X",c:byte()) end)
    local body=table.concat({"HCB1",b.class,b.profile,name,table.concat(steps,","),table.concat(weights,",")},"|")
    return body.."|"..checksum(body)
end
function B:Decode(text)
    if type(text)~="string" or #text>self.maxText then return nil,"Build code is too long." end
    text=text:match("^%s*(.-)%s*$")
    local fields=split(text,"|")
    if #fields~=7 or fields[1]~="HCB1" then return nil,"Paste a HardcoreBuddy HCB1 build code." end
    if checksum(table.concat(fields,"|",1,6))~=fields[7] then return nil,"Incomplete or damaged build code." end
    if #fields[4]%2~=0 or fields[4]:find("[^%x]") then return nil,"Invalid build name." end
    local b={class=fields[2],profile=tonumber(fields[3]),name=fields[4]:gsub("%x%x",function(h) return string.char(tonumber(h,16)) end),steps={},weights={}}
    local keys=self:Nodes(b.class)
    for i,n in ipairs(split(fields[5],",")) do
        local index=tonumber(n)
        if not index or not keys[index] then return nil,"Unknown talent in build code." end
        b.steps[i]=keys[index]
    end
    local values=split(fields[6],",")
    if #values~=#A.GearAdvisor.WeightFields then return nil,"This build uses a different stat-weight format." end
    for i,field in ipairs(A.GearAdvisor.WeightFields) do b.weights[field[1]]=tonumber(values[i]) end
    return self:Validate(b)
end
