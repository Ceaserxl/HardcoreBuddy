"""Explicit offline loader for archived helper policies; never used by the addon."""
from render_layout import boot as boot_addon, ROOT


def boot():
    lua, addon = boot_addon()
    assert addon.RotationHelper is None, 'Shipping TOC must not load the helper'
    for name in ('Engine', 'Mage', 'Runtime', 'Supplies', 'Buffs', 'Glow', 'UI'):
        lua.execute((ROOT / 'RotationHelper' / (name + '.lua')).read_text(encoding='utf-8'),
                    'HardcoreBuddy', addon)
    return lua, addon
