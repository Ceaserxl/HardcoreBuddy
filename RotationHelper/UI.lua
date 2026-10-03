local _,A=...
local H=A.RotationHelper
function H:Document(context)
    if not self.module then self:Rebuild() end
    local supported=self.module~=nil
    local enabled=self:Enabled()
    local card={title="Rotation Helper",note=supported and ("Mage | Assistant "..(enabled and "enabled" or "disabled").." | Solo Hardcore leveling and conservative group support.")
        or "Mage support is available. Other classes will use the same shared rules when added.",gridStart=1,
        headerAction=supported and {label=enabled and "Disable" or "Enable",action={kind="rotationHelperToggle"}} or nil,blocks={
            {title="|cffffd126Main|r",body="One next attack. Planned when your cast starts and held through its finish."},
            {title="|cffff3020Defensive|r",body="Interrupts, control and survival. May appear alongside your next attack."},
            {title="|cffd958ffOffensive|r",body="Ready damage cooldowns and mana recovery. Use when the encounter warrants them."},
            {title="|cff33a6ffPreparation|r",body="Missing or expiring buffs, food, water and mana gems between fights."},
        }}
    if self.Glow.unavailable then card.blocks[#card.blocks+1]={title="Spell glow unavailable",body="This client did not provide Blizzard's spell alert template. Reload after enabling your action bars."} end
    return {context=context,view="training",continuous=true,page=1,pages=1,cards={card,
        {title="Shared rules",fullWidth=true,blocks={
            {title="Your action bars",body="Highlights learned spells and carried items already on your bars, including spell macros. Enable separately on each Mage."},
            {title="Timing & safety",body="Plans your next attack up to 2 seconds ahead or for cast completion. Other highlights require ready cooldowns. Ignores the GCD; respects range, crowd control and learned talents."},
        }}}}
end
