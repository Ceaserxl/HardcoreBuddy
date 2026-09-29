# Creature warning audio

Current runtime sound sets, each in 10% through 100% volume variants:

- `NeutralRareVoiceV1`: "Neutral Rare Detected"
- `HostileRareVoiceV1`: "Hostile Rare Detected"
- `EliteSirenV2`: original synthesized alternating two-tone siren, 2.4 seconds.

Speech rendered locally with Windows System.Speech, Microsoft Zira Desktop,
normal speaking rate. Source recordings retain the `-source.wav` suffix.
The addon plays bundled PCM WAV files and has no runtime speech dependency.

Rebuild speech with `scripts/generate_creature_voices.ps1`, then generate all
volume variants with `scripts/generate_creature_audio_v2.py`. Retired sound sets are excluded from the release.
