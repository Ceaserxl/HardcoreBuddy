"""Boot the release ZIP, validate bundled media, and exercise all alert sounds."""
import io
import sys
import wave
import zipfile
from pathlib import Path

from lupa.lua51 import LuaRuntime
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
archive_path = Path(sys.argv[1])
with zipfile.ZipFile(archive_path) as archive:
    names = set(archive.namelist())
    assert archive.testzip() is None
    assert all(name.startswith('HardcoreBuddy/') for name in names)
    assert not any('/tests/' in name or '/reference/' in name or '/Source/' in name
                   or '__pycache__' in name for name in names)
    lua = LuaRuntime(unpack_returned_tuples=True)
    for mock in ('wow_mock.lua', 'deaths_mock.lua'):
        lua.execute((ROOT / 'tests' / mock).read_text())
    addon = lua.table()
    toc = archive.read('HardcoreBuddy/HardcoreBuddy.toc').decode()
    for entry in toc.splitlines():
        if entry.strip() and not entry.startswith('#'):
            lua.execute(archive.read('HardcoreBuddy/' + entry.replace('\\', '/')).decode(),
                        'HardcoreBuddy', addon)
    lua.globals().TestAddon = addon
    lua.globals().MOCK.FireAll('ADDON_LOADED', 'HardcoreBuddy')

    def require_asset(path, *args):
        path = str(path).replace('\\', '/')
        if path.lower().startswith('interface/addons/hardcorebuddy/'):
            name = path[len('Interface/AddOns/'):]
            assert name in names or name + '.tga' in names, f'Missing asset: {path}'
        return True, 1

    lua.globals().PlaySoundFile = require_asset
    lua.execute('''
        local A=TestAddon; A:ToggleWindow()
        for _,page in ipairs({"supplies","companion","deaths","alerts","dungeons","raids"}) do
            A:Navigate(page)
        end
        local H=A.Deaths
        H.db.settings.sound=true
        for _,choice in ipairs(H.soundChoices) do
            H.db.settings.alertSound=choice.id
            for volume=10,100,10 do
                H.db.settings.volume=volume
                H:PlayAlertSound()
            end
        end
        assert(A.window.footer:GetText():find(A.version,1,true))
    ''')
    for _, frame in lua.globals().MOCK['frames'].items():
        if frame['texture']:
            require_asset(frame['texture'])
    for name in names:
        if name.endswith('.tga'):
            with Image.open(io.BytesIO(archive.read(name))) as image:
                image.load()
        elif name.endswith('.wav'):
            with wave.open(io.BytesIO(archive.read(name))) as audio:
                assert audio.getnframes() > 0
                assert audio.readframes(audio.getnframes())
    print(f'PASS: Release ZIP boots under Lua 5.1; menus, death sounds, custom textures, '
          f'TGA/WAV decoding and version footer verified ({len(names)} files).')

