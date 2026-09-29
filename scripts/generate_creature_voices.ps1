$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$assetRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Media\CreatureSounds'))
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $voice.SelectVoice('Microsoft Zira Desktop')
    $voice.Rate = 0
    $voice.Volume = 100
    foreach ($entry in @(
        @{File='NeutralRareVoiceV1-source.wav'; Text='Neutral Rare Detected'},
        @{File='HostileRareVoiceV1-source.wav'; Text='Hostile Rare Detected'}
    )) {
        $voice.SetOutputToWaveFile((Join-Path $assetRoot $entry.File))
        $voice.Speak($entry.Text)
        $voice.SetOutputToNull()
    }
} finally { $voice.Dispose() }
