# Duskward original GPT Image artwork

Use `manifest.json` for atlas regions. All regions are pixel rectangles `[x, y, width, height]` in the original PNG; do not use fixed-grid slicing. Draw with alpha blending and linear texture filtering. Fully transparent pixels contain background RGB, which must not be shown. Add game shadows separately under the art.

Characters are static three-quarter/top-down ready poses. Scale by each region's aspect ratio rather than stretching to square. Suggested initial in-world heights: heroes 58-70 px, crawler 38 px, skirmisher/shooter 48-54 px, guard 66 px, siege 70 px, boss 112 px, castle 150 px. Runtime movement bob, squash and directional mirroring may be added without changing source art.

Original artwork created using the built-in GPT Image tool for this project. The manifest includes full generation prompts, persisted original paths, dimensions, and inspection notes. No external paid API or command-line image generation was used.
