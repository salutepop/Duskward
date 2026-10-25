# Overlap-aware presentation candidate

## Why this exists

The Android `0f59c90` labeled lower/R and upper/W diagnostic frames showed that the opaque touch controls concealed the player and adjacent guard. The partial red debris perimeter alone did not establish trackability. These are injected frozen screenshot fixtures, not lawful match or human-feel evidence.

## Source-level policy

- No change to the world transform, playable bounds, hit rectangles, pointer ownership, skill targeting, clock, model, or damage geometry.
- Once per draw, collect conservative screen-space bounds for the live hero and enemies, locked enemy attack warnings, active/warning hazards, the locked boss smash cone, and hostile projectiles.
- Sprite bounds share the atlas aspect ratio and 0.83-height anchor used for drawing, with a 4px motion margin. The cannon core uses its actual centered diamond/circle footprint.
- Hostile projectile bounds include previous/current positions, 100ms of velocity lookahead, and at least20px of trail/radius margin. This is only a deterministic paint decision, not projectile simulation, damage prediction, or input smoothing.
- Overlapping skill/potion/stick and floating HUD groups multiply backing opacity by0.12 and large glyph/rim opacity by0.45. Small names, cooldown/lock numbers and HUD text retain0.85 opacity; the mana warning symbol retains that stronger opacity too.
- Unaffected groups retain their original opacity. Paused menus and title screens do not use battlefield fading. Status and contextual action backings use the same geometry rule.
- No opaque actor is redrawn over a button. No red threat outline is repeated over a control. Actual actors, the existing foot ellipse, selected-target marker, warnings and projectiles remain in their original world draw order, revealed through the local fade.
- Opacity updates on the current frame with no timer or easing. It does not invalidate hit targets or cancel a captured pointer.

Public pure diagnostics:

- `control_painted_rects()`: stable names to painted rectangles, distinct from actionable hit rectangles.
- `occlusion_paint_state()`: each rectangle, `occluded`, source tags, `backing_alpha`, `ink_alpha`, and `text_alpha`. Calling this does not mutate the model.

## Explicit debug fixtures

Only debug builds recognize these opt-in `--visual-smoke=` values:

| Flag | Player world position | Purpose |
| --- | --- | --- |
| `corner-lower` |44.2,22|Original R before/after point, unchanged|
| `corner-upper` |44.2,18.3|Original W before/after point, unchanged|
| `left-stick` |4.875,21.8|Left joystick overlap|
| `top-hud` |24,2.5|Floating central HUD overlap|

All four retain the persistent FIXTURE label, explicitly inject guard/debris warning state, freeze simulation/input/navigation, and never save a checkpoint or enable QA autoplay. They are diagnostic screenshots only.

## Evidence still required

`tests/presentation_occlusion.gd` covers source geometry and real Viewport touch/drag events while normal model steps cross an overlap boundary. It checks hit metadata, two-pointer ownership, aim alignment, cancellation, release safety and return to normal paint. It does not establish raster readability, physical size, frame rate or playfeel.

Before accepting the candidate, compare the exact Android lower/upper fixtures; inspect left/top fixtures and bright terrain; confirm underlying player/selected enemy/warnings/hostile projectiles remain trackable while buttons and cooldown/mana/lock states remain recognizable. Then inspect normal moving touch-plus-aim frames and lifecycle behavior. Numeric opacity checks alone are not a visual pass.
