param([string]$Source)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$addonDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([string]::IsNullOrWhiteSpace($Source)) { $Source = Join-Path $addonDirectory 'Media\Source\SupplyRowSquare.png' }
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


# Extract only the straight framed strip; runtime uses equal end caps and a
# stretched center to fit supply rows without distorting the ornaments.
Write-GameTexture $Source (Join-Path $addonDirectory 'Media\SupplyRowSquare.tga') 1024 128 398 153 24 1596




