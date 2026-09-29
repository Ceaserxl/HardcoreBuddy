# Original artwork

## Symmetrical iron banner (active)

`AlertBannerIron.tga` uses the untouched generated source
`Media/Source/DeathAlertBannerIron.png` (2172 x 724). The built-in imagegen
tool created this alternative. `scripts/import_iron_death_banner.ps1` extracts
x=0, y=130, width=2172, height=411 and converts it to 2048 x 512 BGRA TGA.
The centered text and equal end caps retain the 896 x 112 alert geometry.

Prompt: production dark fantasy alert texture; symmetrical forged dark iron
frame, thin silver bevels, muted crimson corner gems, mirrored angular end
pieces, uninterrupted near-black weathered slate center for three centered
text lines, thin straight rails, no skulls, text, watermark or scene.

## Previous centered HardcoreBuddy alert banner

`AlertBannerCentered.tga` is original artwork generated with the built-in
imagegen tool. Its untouched source is `Media/Source/DeathAlertBannerCentered.png`
(2172 x 724). `scripts/import_centered_death_banner.ps1` crops x=0, y=173,
width=2172, height=341 to remove the outer black padding, then writes an
uncompressed 2048 x 512 BGRA TGA.

The 896 x 112 runtime banner uses equal 57px end caps with matching skull
ornaments. The open center stretches between them; all three text lines and
the divider share the full banner's centerline.

Prompt direction: symmetrical Classic fantasy death-alert strip with tiny skull
ornaments at both extreme ends, a thin aged bronze/iron border, restrained red
lower corners and a dark open center for live centered text. No lettering.

## Previous HardcoreBuddy alert banner

`AlertBanner.tga` is new artwork generated for the widened death alert. Its
unaltered source is `Media/Source/DeathAlertBanner.png` (2172 x 724). The import
script `scripts/import_death_banner.ps1` extracts the complete horizontal banner
from the generated black letterbox (x=0, y=132, width=2172, height=396) and writes
an uncompressed 2048 x 512 BGRA TGA. Runtime samples V=26/396 through 378/396
(original source rows 158-510) to exclude the opaque black exterior bands,
displaying the framed strip in a 896 x 112 three-slice banner. The left skull and
right cap scale proportionally to the reduced height; only the middle stretches.
The upper/lower protruding tips are
trimmed to the rectangular frame. The original artwork remains unchanged.
The left skull is retained, with larger left-aligned text beside it.

Prompt: production raster texture for a Classic fantasy death-alert banner;
thin aged bronze and dark iron ornamental border, subtle crimson embers at the
bottom corners, small ivory skull at the far left, almost-black charcoal stone
across the center and right for three live text lines. Crisp restrained RPG UI
craftsmanship; no lettering, numbers, watermark, surrounding scene or mockup.

## Original journal/feed textures

Generated with the built-in imagegen tool for HardcoreDeaths.
These TGAs were copied unchanged into HardcoreBuddy's embedded death module.
PNG originals remain in the sibling `HardcoreDeaths/Media` directory as
`header-source.png` and `icon-source.png`; TGA files are runtime conversions.

## Header prompt

Use case: stylized-concept. Asset type: finished raster texture for the header of a World of Warcraft Classic addon named HardcoreDeaths. Create a wide 3:1 dark fantasy memorial banner. Original hand-painted game UI artwork: an aged bronze skull medallion prominently at the far left, flanked by subtle weathered metal scrollwork, charcoal slate background fading almost to black across the center and right, restrained crimson embers near the bottom edge. Sophisticated Blizzard-inspired readable interface texture, subdued contrast in the middle and right for live text to be placed over it. No letters, words, text, numbers, logos, watermark, or mockup frames. Full bleed rectangular artwork, opaque background. Keep the medallion within the left quarter so the banner can also supply an icon crop.

## Icon prompt

Use case: stylized-concept. Asset type: original square game addon icon for HardcoreDeaths, a hardcore fantasy death journal. A single aged bronze skull medallion, frontal centered view, dark iron rim, tiny muted crimson ember accents, charcoal black background. Hand-painted premium fantasy game UI art, strong simple silhouette readable at 32 pixels, generous margins, fits inside a circle. No text, letters, logos, watermark, swords, characters or extra objects. Opaque square texture.
