# HardcoreBuddy artwork

The version 3 field-journal artwork was created with the built-in imagegen tool.
It is embedded in the addon and requires no website, download or external addon
at runtime. This is an independent addon, not an official Blizzard product.

## Current version 3.1 assets

Active runtime textures: JourneyBanner, SurvivorShield, FieldBackdrop and
SupplyRow. The first two are described below. These new assets were created
with built-in imagegen for the fixed 1040 x 660 layout:

- `Media/FieldBackdrop.tga`: 1024 x 1024 uncompressed BGRA; preserved source
  `Media/Source/FieldBackdrop.png` is 1574 x 999. It stretches once over the fixed
  window without tiling; the navigation strip and quiet map suit the wide layout.
- `Media/SupplyRow.tga`: 2048 x 256 uncompressed BGRA; preserved source
  `Media/Source/SupplyRow.png` is 2172 x 724 with technical padding. Import extracts
  the full row rectangle (14, 259, 2144, 184). Three native texture slices keep
  the metal ends shaped while the quiet middle fills the available row width.

JournalLeather, FieldHeader and LanternCrest are retained development history
and are not used by version 3.1 runtime code.

## Version 3.1 background prompt

Use case: stylized-concept. Production background artwork for a fixed 1040 by 660 native fantasy MMORPG companion interface. Generate a landscape canvas matching that 1040:660 ratio if possible, about 1560 by 990. The artwork is ONLY a background material, no UI mockup, text, buttons, windows or panels. A premium adventurer's field kit interior: near-black charcoal blue waxed canvas and very dark umber leather, restrained seams along the outermost edges, faint hand-drawn map contour lines and worn compass marks embossed into the grain, tiny worn steel and aged brass highlights at corners, understated moss-gray scuffs. The entire center 90 percent is extremely low contrast and quiet, suited for ivory text and many overlaid item rows. Material detail should be delicate and atmospheric, not bright ornate curls or busy wallpaper. Top 18 percent dark charcoal empty material where a separate forest banner will sit. Left 18 percent equally dark for navigation. No objects intruding into text area, no lettering, readable symbols, skulls, emblems, campfires, lanterns, outer frame, watermark, shine or gradients that wash out text. Hand-painted classic Warcraft-era game UI material with convincing subtle tactile depth, cohesive with a dark misty forest banner, a silver skull shield crest, and bronze native frame. Edge to edge opaque material; do not leave white margins.

## Version 3.1 line-item artwork prompt

Use case: stylized-concept. Asset type: ONE premium horizontal item-row background for a classic fantasy MMORPG interface, no mockup. Important canvas layout: a wide3:1 canvas with a very shallow finished horizontal row panel ONLY in the middle third of the canvas height, full canvas width; top third and bottom third are completely black technical padding. The middle strip is approximately9:1 and will be extracted. Create a hand-painted beveled rectangular inset of very dark slate leather with a refined thin worn bronze and steel rim. The long center is extremely quiet flat dark charcoal with subtle fine grain, intended to receive white item text. At both left and right ends compact matched metal corner caps with small bronze rivets and subtle beveled highlights; edge details stay within the outermost5percent of width. The central90percent contains no objects or symbols; top and bottom edges are straight parallel slim bands, suitable for stretching the center while keeping the end caps fixed. Clean readable depth like a Blizzard game item slot, with a tiny warm edge highlight and deep inset shadow. Fully rectangular shape, all corners and edges fully inside the middle horizontal strip. No gold filigree, glow, icon, skull, lettering, numbers, UI controls, colored gems or watermark. No transparency needed; artwork opaque. Do not draw a whole window or multiple panels. This is one single empty item row. The padded3:1 canvas and centered shallow9:1 strip are intentional.

## Earlier delivered assets

- `Media/JourneyBanner.tga`: 2048 x 256, uncompressed 32-bit BGRA TGA. The complete
  shallow scene occupies a 2172 x 240 strip at (0, 239) in the preserved generated
  source `Media/Source/JourneyBanner.png` (2172 x 724). The rest is intentional
  letterbox padding from generation. Its visual aspect is 2172/240 = 9.05:1.
- `Media/SurvivorShield.tga`: 256 x 256, uncompressed 32-bit BGRA TGA with alpha;
  original retained as `Media/Source/SurvivorShield.png` (1254 x 1254).
- `Media/JournalLeather.tga`: 512 x 512 tiled dark leather material; original
  retained as `Media/Source/JournalLeather.png`.

`scripts/import_art.ps1` reproducibly imports the preserved PNGs into game texture
formats with .NET System.Drawing. The banner import extracts the complete artwork
strip from its technical padding, then resamples into a power-of-two texture.
At runtime the panorama fills the entire header. Centered texture-coordinate
cropping preserves the original 9.05:1 scene proportions without stretching or
unused side space. A soft native gradient behind the title preserves contrast.
The journal shield is 92 pixels and vertically centered in the header; the
minimap launcher uses its own compact size.
Artwork is decorative and never intercepts mouse input.

The former `FieldHeader` and `LanternCrest` files are retained as development
history and are not referenced by version 3.0.2 runtime code.

The game supplies its native dialog border, button bevels and icon rims. Those
Blizzard textures are referenced by native paths rather than bundled with the
addon. Development layout previews use a separate cache of the native assets.

## Version 3.0.2 banner generation prompt

Use case: stylized-concept. Create a finished production background texture for the shallow header of a native World of Warcraft Classic Hardcore companion addon. This is the banner artwork itself, not an application screenshot or a UI mockup. EXTREMELY WIDE AND SHALLOW CANVAS, exactly 8:1 aspect ratio, 3072 pixels wide by 384 pixels high if possible. Design the composition for this ratio from the beginning; do not crop a normal landscape. Rich hand-painted classic fantasy game art, dark pine forest valley at dusk, slate blue mist, distant ruined watchtower silhouette. In the RIGHTMOST 30 percent a very small complete adventurer campsite: glowing ember campfire, a rolled bedroll and weathered shield leaning against a low rock, grounded and reassuring; every campsite object completely contained within the middle 60 percent of the image height with ample dark sky and ground clearance. The LEFT 60 percent is exceptionally quiet, near-black charcoal blue forest mist, low contrast with no objects and no bright spots, to support gold title text over it. The scene and all objects are appropriately small for a very shallow panoramic strip. All FOUR outer edges fade gently to the SAME almost-black charcoal color RGB approximately 9,12,12, especially the left edge, so the texture can be placed on a matching dark panel at different widths without a visible seam. No border, frame, emblem, lettering, numbers, UI controls, watermark, humans, large close-up objects, journal, or lantern. Refined painterly game asset, no photorealism. Opaque background. Fill the 8:1 canvas edge to edge.

## Version 3.0.2 final banner edit prompt

Use case: precise-object-edit. Edit the provided forest campsite artwork into a true SHALLOW game-interface banner without losing complete objects. Input image is the visual style and scene reference. CRITICAL OUTPUT LAYOUT: keep a wide 3:1 canvas, but the final banner artwork must occupy ONLY a very thin horizontal strip across the EXACT MIDDLE of the canvas. The upper 31.25 percent and lower 31.25 percent of the canvas must be completely empty solid black letterbox bars. The center 37.5 percent of the canvas height contains the complete scene, edge to edge horizontally. This center strip therefore has an exact 8:1 aspect ratio, and it will be extracted as the actual header asset. Recompose all existing scenery to live ENTIRELY inside that center strip, no tower top or flame or shield extending into the bars. Do not squash objects. Simplify the scene as necessary: low distant mountains, small whole ruined tower, small whole campfire and whole shield on far right. Left 60 percent of the center strip is quiet very dark charcoal forest haze suitable for gold text; right 30 percent contains all campsite objects as SMALL complete objects with vertical breathing room. Keep the same hand-painted classic fantasy style, dark slate and ember colors. The center strip's first and last 8 percent of width gently fade into near-black RGB9,12,12 to join a matching native header backdrop invisibly. Absolutely no text, numbers, frames, logos or UI controls. Do not merely crop the input landscape: REDRAW the scene with a genuinely shallow composition inside that middle strip. Black letterbox margins outside are intentional technical padding.

The generated edit placed the strip at rows 239 through 478. Import uses those
observed artwork bounds instead of the requested padding proportions.

## Version 3.0.2 shield prompt

Use case: stylized-concept. Create one original premium World of Warcraft Classic Hardcore companion addon emblem, designed to remain exceptionally clear at 56 pixels and 24 pixels. Asset type: square transparent PNG game interface icon. A compact sturdy kite-shaped dark iron SHIELD with thick bevelled weathered silver-steel edges and a thin aged brass inner rim. At the center one large simple stylized ivory SKULL with dark eye sockets, readable heroic fantasy symbol, no blood, no gore. Deep muted oxblood-red enamel behind the skull; a tiny torn red cloth tab at the bottom. Hand-painted classic fantasy MMORPG interface artwork with strong volume, bright upper edge highlights and dark engraved recesses, restrained detail and crisp silhouette. The shield is the dominant entire object, front view, centered, symmetric, occupies about 86 percent of the square; no extra weapons, no wings, no laurel, no circular medallion, no lantern, no letters, no words, no watermark, no outer frame. Genuinely transparent alpha background outside the shield, no checkerboard or solid backdrop, no wide drop shadow. Canvas 1024 by 1024. Distinct iconic silhouette rather than busy filigree.

## Original version 3.0 header prompt (superseded)

Use case: stylized-concept. Asset type: production background artwork for the header of a native World of Warcraft Classic Hardcore companion addon, not a mockup or screenshot. Generate a very wide 3:1 landscape composition, 1536 by 512 pixels if possible. A beautifully hand-painted dark fantasy expedition scene: on the far right a weathered adventurer's leather journal, rolled parchment maps, small glass healing vial and a warm amber camping lantern resting on old stone beneath a gnarled tree; misty pine forest and ancient stone arch in the distance. Rich Warcraft-era painterly game interface illustration, bold readable silhouettes, handcrafted bronze details, muted moss and charcoal shadows, restrained ember orange glow. The left 60 percent is quiet dark charcoal and very subtle forest haze so native UI title text can be laid over it, no busy forms there. The lower edge naturally fades to near-black brown. Expensive game production quality, atmospheric, detailed but restrained. Fill the entire canvas edge to edge. No lettering, no numbers, no logo, no watermark, no UI controls, no outer frame. This image will be embedded in the addon.

## Original version 3.0 crest prompt (superseded)

Use case: stylized-concept. Asset type: square emblem texture for a premium native World of Warcraft Classic Hardcore companion addon. Generate a single exquisite hand-painted fantasy game crest, an old bronze and dark iron circular medallion with an amber-lit adventurer's lantern in its center, two small crossed weathered swords behind it and restrained laurel details, leather straps, tiny red enamel accent. Substantial three dimensional carved and beveled rim with warm specular highlights, charcoal recesses. Heroic, rugged, reassuring, not scary. The medallion fills 85 percent of the square, fully visible with a little padding. Crisp readable silhouette at 64 pixels, authentic handcrafted 2004 fantasy MMORPG interface art, polished high-end game asset quality. Isolated with a genuinely transparent background and preserved alpha; no shadow beyond a small soft contact shadow. Centered and symmetrical, no text, no initials, no logo, no watermark. 512 by 512 pixels if possible. This will be embedded as the addon crest and minimap launcher icon.

## Final material prompt

Use case: stylized-concept. Asset type: seamless tileable background material for a luxury fantasy MMORPG adventurer's journal user interface, not a complete UI. Square 1024 by 1024. A close-up orthographic flat scan of extremely dark warm umber leather and charcoal parchment, fine natural grain, faint hand-tooled curling leaf filigree and hairline embossed scrollwork, very subtle tarnished bronze dust in the grain. Low contrast, mostly dark rich walnut brown with barely visible detail, softly burnished but matte, no dominant shapes, no directional light, no edge border or vignette, no objects, no lettering, no glyphs, no symbols, no logo. Repeating seamlessly on all four edges. Luxurious authentic hand-painted Warcraft-era game material. Uniform quiet visual density suited to sitting behind readable ivory text. Original game production texture, not photoreal.
