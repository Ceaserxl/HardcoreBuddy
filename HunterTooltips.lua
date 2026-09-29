local _,addon=...
local H={pets=addon.Data.Beasts or {}}
addon.HunterTooltips=H
-- Compatibility signal for the installed Tamed tooltip hook.
HardcoreBuddyHunterTooltips=H

function H:Add(tooltip)
    local _,class=UnitClass("player")
    if class~="HUNTER" then return end
    local _,unit=tooltip:GetUnit()
    if not unit or (UnitIsPlayer and UnitIsPlayer(unit)) then return end
    local guid=UnitGUID(unit)
    if not guid then return end
    local kind,id=guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)%-")
    if kind~="Creature" then return end
    local pet=self.pets[tonumber(id)]
    if not pet or tooltip.hardcoreBuddyPetGUID==guid then return end
    tooltip.hardcoreBuddyPetGUID=guid
    local controlled=UnitPlayerControlled and UnitPlayerControlled(unit)
    local tameable=pet.tameable and not controlled
    tooltip:AddLine(tameable and "Tamable" or "Untamable",tameable and 0.45 or 0.95,tameable and 0.85 or 0.4,0.45)
    if tameable then
        for _,skill in ipairs(pet.abilities or {}) do
            local name,rank=skill:match("^(.-)%s+(%d+)$")
            local icon=addon.Data.PetSkillIcons[name or skill] or "ability_hunter_beasttaming"
            local text=name and (name.." (Rank "..rank..")") or skill
            tooltip:AddLine("|TInterface\\Icons\\"..icon..":16:16:0:0|t "..text,0.94,0.90,0.79)
        end
        if not pet.abilities then tooltip:AddLine("Pet skills not verified",0.65,0.65,0.56)
        elseif #pet.abilities==0 then tooltip:AddLine("No innate pet skills",0.65,0.65,0.56) end
        local level=UnitLevel and UnitLevel(unit)
        local playerLevel=UnitLevel and UnitLevel("player")
        if playerLevel and playerLevel<10 then tooltip:AddLine("Requires Tame Beast at level 10",0.95,0.65,0.3)
        elseif level and playerLevel and level>playerLevel then tooltip:AddLine("Above your level",0.95,0.65,0.3) end
    end
end

if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit",function(tooltip) H:Add(tooltip) end)
    GameTooltip:HookScript("OnTooltipCleared",function(tooltip) tooltip.hardcoreBuddyPetGUID=nil end)
end
