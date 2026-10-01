# Deathlog death-alert sounds

The five original `.ogg` clips come from
[Deathlog / DeathNotificationLib](https://github.com/aaronma37/Deathlog/tree/1092449ed714e70ddfdc6111e575e15a27589933/Libs/DeathNotificationLib/Sounds).
Upstream license: GNU GPL version 3; see `LICENSE.txt`. Original filenames and
unmodified source clips are retained here. `sources.json` records hashes and URLs.

HardcoreBuddy's numbered copies change only the playback gain, to provide an
independent 0-100% alert volume without changing the game's sound settings.
Rebuild with `scripts/import_deathlog_sounds.py PATH_TO_FFMPEG`.
All five are selectable in the Death Journal options alongside the custom bell and the default
original WoW raid-warning sound (kit 8959, also Deathlog's default). Volume-adjusted
copies of that Blizzard clip ship separately in ../Original with their source
attribution. Deathlog itself is not required.
