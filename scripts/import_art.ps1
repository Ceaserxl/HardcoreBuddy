param(
    [string]$HeaderSource,
    [string]$CrestSource,
    [string]$MaterialSource,
    [string]$BackgroundSource,
    [string]$RowSource
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$addonDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$mediaDirectory = Join-Path $addonDirectory 'Media'
$sourceDirectory = Join-Path $mediaDirectory 'Source'
[IO.Directory]::CreateDirectory($sourceDirectory) | Out-Null

function Copy-ArtSource([string]$sourcePath, [string]$name) {
    $destination = Join-Path $sourceDirectory $name
    if ([string]::IsNullOrWhiteSpace($sourcePath)) { $sourcePath = $destination }
    $resolvedSource = (Resolve-Path -LiteralPath $sourcePath).Path
    if (-not [string]::Equals($resolvedSource, $destination, [StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item -LiteralPath $resolvedSource -Destination $destination -Force
    }
    return $destination
}

function Write-GameTexture([string]$sourcePath, [string]$destination, [int]$width, [int]$height, [int]$cropTop = 0, [int]$cropHeight = 0, [int]$cropLeft = 0, [int]$cropWidth = 0) {
    # WoW accepts uncompressed 32-bit BGRA TGA with power-of-two dimensions.
    # This is a format/size conversion; the generated source is preserved above.
    $source = [Drawing.Image]::FromFile($sourcePath)
    if ($cropHeight -eq 0) { $cropHeight = $source.Height }
    if ($cropWidth -eq 0) { $cropWidth = $source.Width }
    if ($cropTop -lt 0 -or $cropHeight -lt 1 -or $cropTop + $cropHeight -gt $source.Height -or $cropLeft -lt 0 -or $cropWidth -lt 1 -or $cropLeft + $cropWidth -gt $source.Width) {
        $source.Dispose()
        throw 'Artwork extraction rectangle is outside the source image.'
    }
    $bitmap = New-Object Drawing.Bitmap($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.Clear([Drawing.Color]::Transparent)
            $destinationRect = New-Object Drawing.Rectangle(0, 0, $width, $height)
            $graphics.DrawImage($source, $destinationRect, $cropLeft, $cropTop, $cropWidth, $cropHeight, [Drawing.GraphicsUnit]::Pixel)
        }
        finally { $graphics.Dispose() }

        $header = New-Object byte[] 18
        $header[2] = 2 # Uncompressed true-color image.
        $header[12] = $width -band 255
        $header[13] = ($width -shr 8) -band 255
        $header[14] = $height -band 255
        $header[15] = ($height -shr 8) -band 255
        $header[16] = 32
        $header[17] = 40 # Eight alpha bits and top-left origin.
        $rectangle = New-Object Drawing.Rectangle(0, 0, $width, $height)
        $pixels = $bitmap.LockBits($rectangle, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $stream = [IO.File]::Create($destination)
            try {
                $stream.Write($header, 0, $header.Length)
                $row = New-Object byte[] ($width * 4)
                for ($index = 0; $index -lt $height; $index++) {
                    $pointer = [IntPtr]::Add($pixels.Scan0, $index * $pixels.Stride)
                    [Runtime.InteropServices.Marshal]::Copy($pointer, $row, 0, $row.Length)
                    $stream.Write($row, 0, $row.Length)
                }
            }
            finally { $stream.Dispose() }
        }
        finally { $bitmap.UnlockBits($pixels) }
    }
    finally { $bitmap.Dispose(); $source.Dispose() }
    Write-Output ('Imported {0} ({1} x {2}, uncompressed BGRA TGA)' -f [IO.Path]::GetFileName($destination), $width, $height)
}

$headerOriginal = Copy-ArtSource $HeaderSource 'JourneyBanner.png'
$crestOriginal = Copy-ArtSource $CrestSource 'SurvivorShield.png'
$materialOriginal = Copy-ArtSource $MaterialSource 'JournalLeather.png'
$backgroundOriginal = Copy-ArtSource $BackgroundSource 'FieldBackdrop.png'
$rowOriginal = Copy-ArtSource $RowSource 'SupplyRow.png'
# The generated source intentionally includes letterbox padding. Extract its
# complete 2172 x 240 artwork strip; Skin.lua restores that 9.05:1 visual aspect.
Write-GameTexture $headerOriginal (Join-Path $mediaDirectory 'JourneyBanner.tga') 2048 256 239 240
Write-GameTexture $crestOriginal (Join-Path $mediaDirectory 'SurvivorShield.tga') 256 256
Write-GameTexture $materialOriginal (Join-Path $mediaDirectory 'JournalLeather.tga') 512 512
Write-GameTexture $backgroundOriginal (Join-Path $mediaDirectory 'FieldBackdrop.tga') 1024 1024
# Extract the full metal-edged panel from the generated technical padding.
Write-GameTexture $rowOriginal (Join-Path $mediaDirectory 'SupplyRow.tga') 2048 256 259 184 14 2144
