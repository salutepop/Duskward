# Duskward asset validation (2026-10-24 UTC)

## Delivered source images

- `characters_atlas_v1.png`: 1536 × 1024 RGBA, 12 objects, 2,566,866 bytes.
- `battlefield_v1.png`: 1672 × 941 RGB, 2,672,025 bytes.
- `items_atlas_v1.png`: 1536 × 1024 RGBA, 24 catalog items, 2,443,364 bytes.
- `app_icon_v1.png`: 1254 × 1254 RGB, 2,033,596 bytes.

The original generation outputs remain at the exact paths recorded in `manifest.json`. Copies in this project are byte-preserving. All images used the built-in GPT Image tool, not a paid API or CLI.

## Inspected and verified

- Full-size visual inspection performed for all four originals.
- Character atlas: 55.7943% of pixels are exactly alpha 0; 36.1975% have alpha >= 224.
- Item atlas: 61.3363% of pixels are exactly alpha 0; 29.8496% have alpha >= 224.
- Alpha maximum is 254, not 255. This is near-opaque output, not evidence that the background is opaque.
- Transparent pixels retain RGB color. An image viewer that ignores alpha displays gradient backgrounds; proper RGBA blending must ignore them.
- Exact measured object rectangles are in the manifest. The generator did not fully preserve requested gutters, so uniform grid slicing is invalid.
- Connected-component inspection at alpha > 48 found no foreign object contamination in any of the 24 item rectangles.
- Character regions other than guard/portal have no foreign components above that threshold.
- Guardian / ranger / arcanist identity and all five enemy roles are visually distinct. Heroes use cyan, brass and slate; hostiles use red/violet and dark iron.
- App icon essential crystal and gate are centered; the full silhouette approximately fits an inscribed circle. It is an ordinary full-bleed icon, not separate adaptive foreground/background layers. Let the engine export resize.

## Known issue awaiting actual game rendering

The guard rectangle includes 200 alpha > 48 pixels from the adjacent portal tip, while the portal rectangle includes 573 pixels from the guard's foot. At current proposed render sizes these correspond to approximately 8 and 41 output pixels, respectively. This may look like tiny disconnected fragments. Keep the source unmodified. Inspect emulator screenshot and, if visibly defective, request a targeted GPT Image edit rather than programmatically removing background or masks.

## Texture budget

Each source texture is about 6 MiB when decoded as RGBA8 without mipmaps. Expected terrain + characters + items residency is approximately 18 MiB. Including the app icon as a runtime texture makes about 24 MiB. Source PNG total is about 9.27 MiB. Current Godot imports use lossless texture compression, `process/fix_alpha_border=true`, and no mipmaps. These are theoretical texture sizes, not measured total application RAM or GPU allocation.

## Actual Android title inspection (2026-10-24 18:13 UTC)

Evidence: `qa/screenshots/android30-5aa3-normal-scene.png`, normal immutable 5aa3 APK, Android API30 with ANGLE, screenshot800x480. This is actual Android application rendering, not a mockup or an injected visual scene.

- Three hero portraits render with genuine alpha. No opaque rectangular gradient backplates or visible adjacent-object fragments appear.
- Shield, bow and staff silhouettes remain distinct at approximately94px rendered height. Portrait crops preserve weapons and bodies. The hero source artwork does not need regeneration on this evidence.
- Palette is coherent with the slate/teal UI and gold selection outline.
- Secondary Korean card descriptions are small and muted at this screenshot scale. Approximate12px text antialiasing prevents full nominal foreground color coverage; a brightest sampled body pixel is RGB(138,160,162), below nominal(146,168,170). Main title and hero names are clear. Suggested UI-only improvement: description font19 to21/22 logical pixels, maintaining fit, and slightly brighter role labels. This is not an art defect.
- No physical-phone handling, touch comfort or performance claim is inferred from this emulator still frame.

## Actual Android preparation and shop inspection (2026-10-24 18:18 UTC)

Evidence: `qa/screenshots/android30-5aa3-manual-preparation.png` and `qa/screenshots/android30-5aa3-manual-shop-page1.png`, same normal5aa3 APK on API30/ANGLE at800x480. QA reached both screens through normal application controls and retained exclusive emulator input.

- Preparation: terrain aspect-preserving crop, castle and guardian blend correctly with alpha. No opaque atlas rectangles appear. Castle at approximately95px and guardian at approximately37px remain identifiable; the cyan player ring provides useful separation from the detailed stone terrain.
- Portal at approximately58px remains readable. A tiny light fleck above/right of its silhouette is consistent with the statically identified guard-foot contamination. It is a minor polish defect at this resolution, not a blocking artifact. No regeneration is justified without prioritizing it against remaining gameplay work.
- Shop page1: all12 displayed item icons are distinct at approximately30–35px. No adjacent-cell contamination, clipping of major object bodies, or unwanted rectangular background is visible. The selected iron blade detail is clean. Dimmed locked items are intentional UI state.
- The first12 item artworks and hero/castle/terrain composition need no asset regeneration on this evidence. This does not validate the unseen page2, combat enemies, motion stability, or physical-phone readability/handling.

## Actual Android shop page2 inspection (2026-10-24 18:23 UTC)

Evidence: `qa/screenshots/android30-5aa3-manual-shop-page2.png`, normal5aa3/API30/ANGLE,800x480. All12 remaining item icons are visible, covering the complete24-item catalog together with page1. Glaive, ring, advanced relics and healing potion retain distinct silhouettes around30px. No neighboring-item fragments, rectangular backgrounds or major-object clipping are visible. No icon regeneration is needed. Locked-card labels are dimmed by the UI; that is not missing artwork.

## Actual Android early-combat inspection (2026-10-24 18:38 UTC)

Evidence, all normal immutable5aa3/API30/ANGLE at800x480:

- `qa/screenshots/android30-5aa3-manual-wave1-start.png`
- `qa/screenshots/android30-5aa3-manual-joystick-move.png`
- `qa/screenshots/android30-5aa3-manual-skill-Q.png`
- `qa/screenshots/android30-5aa3-manual-Q-alive.png`

Crawlers have clean transparent edges and readable red/black beetle silhouettes around23px on stone. Same-red creatures merge briefly with the portal while directly overlapping it, then separate on the lane. Multiple approaching crawlers remain distinct. The cyan player ring stays identifiable during close overlap. The wave2 shooter reads as a larger purple humanoid, distinct from crawlers. Red attack-warning rings remain visible over the castle and its cyan core in the respawn frame.

These screenshots do not capture the transient Q slash itself. A cooldown display is not evidence of visual-effect animation quality. No claim is made about motion stability, frame rate, physical-phone touch comfort, later enemy types, or the newer0.2 branch. No additional image generation was needed for these observed scenes.

## Pending

Guard/skirmisher/siege/boss rendering and guard cropping, transient skill/projectile effects and motion, exported Android launcher appearance, and draw-call/texture residency measurement. Title heroes, terrain/castle/player, all24 shop icons, crawlers, the wave2 shooter, and sampled attack-warning rings are verified at this emulator resolution in5aa3; unseen scenes and newer builds are not signed off. Desktop Xvfb/Chromium routes are not being used. QA exclusively controls emulator input.

