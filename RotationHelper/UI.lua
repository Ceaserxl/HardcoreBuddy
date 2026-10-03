local _,A=...
local H=A.RotationHelper
function H:Document(context)
    if not self.module then self:Rebuild() end
    local supported=self.module~=nil
    local enabled=self:Enabled()
    local scope=self.module and self.module.suppliesOnly and "Buff preparation" or "Solo Hardcore leveling and conservative group support"
    local card={title="Rotation Helper",note=supported and (self.module.name.." | Assistant "..(enabled and "enabled" or "disabled").." | "..scope..".")
        or "Buff preparation supports Classic classes. Combat rotation advice supports Mage.",gridStart=1,
        headerAction=supported and {label=enabled and "Disable" or "Enable",action={kind="rotationHelperToggle"}} or nil,blocks={
            {title="|cffffd126Main|r",body="One next attack. Chosen at cast start and held through completion until you start the next action."},
            {title="|cffff3020Defensive|r",body="Interrupts, control and survival. May appear alongside your next attack."},
            {title="|cffd958ffOffensive|r",body="Ready damage boosts for your next attack and mana gems. Optional alongside Main."},
            {title="|cff33a6ffPreparation|r",body="Your strongest non-conflicting buffs, carried elixirs, scrolls, food and water between fights. Refreshes at 5 minutes remaining."},
        }}
    if self.module and self.module.suppliesOnly then card.blocks={card.blocks[4]} end
    if self.Glow.unavailable then card.blocks[#card.blocks+1]={title="Spell glow unavailable",body="This client did not provide Blizzard's spell alert template. Reload after enabling your action bars."} end
    return {context=context,view="training",continuous=true,page=1,pages=1,cards={card,
        {title="Shared rules",fullWidth=true,blocks={
            {title="Your action bars",body="Highlights learned spells and carried items already on your bars, including macros. Enable separately on each character. Combat rotation advice is Mage-only."},
            {title="Timing & safety",body=self.module and self.module.suppliesOnly
                and "Buffs respect class, level, bags and cooldowns. Stronger active buffs suppress weaker replacements. Preparation waits until you leave combat."
                or "Prefers an affordable, ready attack. Can anticipate mana recovery by 2 seconds when none is ready. Respects range, crowd control and talents."},
        }}}}
end
