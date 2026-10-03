-- Pure, class-independent selection. No game APIs, frames or saved combat history.
local _,A=...
local H={classes={},lead=2,colors={main={1,0.82,0.15},defensive={1,0.18,0.12},offensive={0.85,0.35,1},preparation={0.2,0.65,1}}}
A.RotationHelper=H

function H.Eligible(c,key,immediate)
    local s=c.spells[key]
    if not s or not s.known or s.blocked or c.dead or c.taxi then return false end
    if s.enemy and (not c.hostile or c.controlled or s.range~=true or c.immune[key]) then return false end
    if s.range==false then return false end
    local lead=immediate and 0 or math.max(H.lead,c.cast and c.cast.remaining or 0)
    if (s.cooldown or 0)>lead then return false end
    local power=immediate and c.power or c.futurePower
    return s.cost<=power
end

function H.Select(c,module,state)
    state=state or {}
    if c.dead or c.taxi or c.paused or not module then
        state.lock=nil; state.token=nil; state.target=nil
        return {},state
    end
    local primary,extras,groups=nil,{},{}
    local rules={}
    for _,rule in ipairs(module.rules) do rules[#rules+1]=rule end
    for _,rule in ipairs(H.sharedRules or {}) do rules[#rules+1]=rule end
    for _,rule in ipairs(rules) do
        if H.Eligible(c,rule.spell,rule.category~="main") then
            local reason=rule.when(c)
            if reason then
                local pick={key=rule.spell,id=c.spells[rule.spell].id,kind=c.spells[rule.spell].kind or "spell",
                    category=rule.category,reason=reason}
                if rule.category=="main" then primary=primary or pick
                elseif not groups[rule.group or rule.spell] then
                    groups[rule.group or rule.spell]=true; extras[#extras+1]=pick
                end
            end
        end
    end
    -- Commit an existing next action; an empty plan may fill after resources
    -- recover. Recheck cooldowns without substituting a late recommendation.
    local token=c.cast and c.cast.token
    if c.targetGUID~=state.target then state.lock=nil; state.token=nil; state.holdUntil=0 end
    state.target=c.targetGUID
    if token then
        if token~=state.token or not state.lock then state.lock=primary; state.token=token end
        state.holdUntil=(c.cast.finish or c.now+c.cast.remaining)+0.25
        primary=state.lock
    elseif state.token and c.now<(state.holdUntil or 0) then
        if not state.lock then state.lock=primary end
        primary=state.lock
    else state.lock=nil; state.token=nil end
    -- Invalid targets/range hide a committed action, never replace it mid-cast.
    if primary and not H.Eligible(c,primary.key,false) then primary=nil end
    local result,seen={},{}
    if primary then result[1]=primary; seen[primary.key]=true end
    for _,pick in ipairs(extras) do
        if not seen[pick.key] then result[#result+1]=pick; seen[pick.key]=true end
    end
    return result,state
end
