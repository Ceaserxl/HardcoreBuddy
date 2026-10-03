-- Pure, class-independent selection. No game APIs, frames or saved combat history.
local _,A=...
local H={classes={},lead=2,colors={main={1,0.82,0.15},defensive={1,0.18,0.12},offensive={0.85,0.35,1},preparation={0.2,0.65,1}}}
A.RotationHelper=H

function H.Eligible(c,key,immediate)
    local s=c.spells[key]
    if not s or not s.known or s.blocked or c.dead or c.taxi then return false end
    if s.enemy and (not c.hostile or c.controlled or s.range~=true or c.immune[key]) then return false end
    if s.range==false then return false end
    local power=immediate and c.power or c.futurePower
    return s.cost<=power
end

function H.Select(c,module,state)
    state=state or {}
    if c.dead or c.taxi or c.paused or not module then
        state.lock=nil; state.hint=nil; state.token=nil; state.target=nil
        return {},state
    end
    local primary,readyMain,hint,extras,groups=nil,nil,nil,{},{}
    local horizon=math.max(H.lead,c.cast and c.cast.remaining or 0)
    local rules={}
    for _,rule in ipairs(module.rules) do rules[#rules+1]=rule end
    for _,rule in ipairs(H.sharedRules or {}) do rules[#rules+1]=rule end
    for _,rule in ipairs(rules) do
        if H.Eligible(c,rule.spell,rule.category~="main") then
            local reason=rule.when(c)
            if reason then
                local pick={key=rule.spell,id=c.spells[rule.spell].id,kind=c.spells[rule.spell].kind or "spell",
                    category=rule.category,reason=reason}
                local ready=(c.spells[rule.spell].cooldown or 0)<=(rule.category=="main" and horizon or 0)
                if rule.category=="main" then
                    primary=primary or pick
                    if ready then readyMain=readyMain or pick end
                else
                    local group=rule.group or rule.spell
                    -- Keep the preferred hint, but let a ready emergency action
                    -- coexist when that hint is still cooling down.
                    if not groups[group] or ready and not groups[group].ready then
                        extras[#extras+1]=pick; groups[group]={ready=ready}
                    end
                end
            end
        end
    end
    if primary and readyMain and primary.key~=readyMain.key then
        hint=primary; hint.category="offensive"; primary=readyMain
    end
    -- Commit an existing next action; an empty plan may fill after resources
    -- recover. A cooling-down attack stays visible as an optional hint.
    local token=c.cast and c.cast.token
    if c.targetGUID~=state.target then state.lock=nil; state.hint=nil; state.token=nil; state.holdUntil=0 end
    state.target=c.targetGUID
    if token then
        if token~=state.token or not state.lock then state.lock=primary; state.hint=hint; state.token=token end
        state.holdUntil=(c.cast.finish or c.now+c.cast.remaining)+0.25
        primary,hint=state.lock,state.hint
    elseif state.token and c.now<(state.holdUntil or 0) then
        if not state.lock then state.lock=primary; state.hint=hint end
        primary,hint=state.lock,state.hint
    else state.lock=nil; state.hint=nil; state.token=nil end
    -- Invalid targets/range hide a committed action, never replace it mid-cast.
    if primary and not H.Eligible(c,primary.key,false) then primary=nil end
    local result,seen={},{}
    if primary then result[1]=primary; seen[primary.key]=true end
    if hint and H.Eligible(c,hint.key,false) then result[#result+1]=hint; seen[hint.key]=true end
    for _,pick in ipairs(extras) do
        if not seen[pick.key] then result[#result+1]=pick; seen[pick.key]=true end
    end
    return result,state
end
