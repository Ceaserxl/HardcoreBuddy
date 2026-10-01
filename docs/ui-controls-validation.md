# Journal, talents and layout update

The requested changes are implemented without runtime interaction with Zygor.

- Talent settings offer one-click allocation and per-character opt-in automation.
  Allocation rereads the live tree and waits for each server-confirmed rank.
  Preview mode, combat, disabled advice, divergent paths and timeouts stop it.
- Journal history uses configurable 1–3650-day retention (30 by default).
  Clearing requires a second click within five seconds and cancels an import.
  History import, alerts and appearance share Settings > Death Journal.
- Supplies, Spells, Zones and zone browsing use two-column cards. Reports have
  no sidebar and adapt their columns to the wider content area.
- Native transparent map/tracking symbols replace square portrait choices.
- The model viewer resolves the creature display with PlayerModel, then uses
  a ModelScene actor's maximum bounding box. A normalized bounding sphere fits
  both viewport dimensions and remains centered during rotation. The scene fills
  its panel with only the one-pixel border inset. Loading and bounded retries remain.
- Page decoration uses background regions, with separate window, popup and
  picker levels. The reparented Death Journal rebases its child frame levels.

Classic Era API signatures checked against Blizzard's generated interface source:

Runtime correction: Classic Era's `GetMaxBoundingBox()` returns six numeric
coordinates, despite generated documentation describing two vectors. The viewer
accepts both shapes. `tests/run_model_bounds.py` reproduces the reported
Verdantine Boughguard coordinates, checks 730 subsequent frames, and exercises
invalid bounds, thrown API errors, retry limits and recovery. The default model
mock now returns the six-number Classic shape.

- [Character model display resolution](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICharacterModelBaseDocumentation.lua)
- [Actor bounding boxes and transforms](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPIModelSceneFrameActorBaseDocumentation.lua)
- [Scene camera and lighting](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPIModelSceneFrameDocumentation.lua)

Offline checks include nine-class talent allocation with delayed acknowledgment,
retention boundaries and import cancellation, a large off-center dragon fixture,
rotation and viewport geometry, grid placement, carry edits, section layering,
navigation/hit testing, existing gear/companion/journal regressions and release
package boot. `tests/run_requested_controls.py` covers the new behavior.

These checks do not render real game models or exercise a live talent server.
In-game acceptance: reload, view Blacklash and several other large creatures,
rotate/zoom/reset, page a cluster, apply unused points on a matching path, and
check native tracking textures and scroll/click behavior with other addons open.
