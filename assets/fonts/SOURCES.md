# Bundled Korean UI fonts

Unmodified Pretendard 1.3.9 static OpenType files from the author's official repository:

- https://github.com/orioncactus/pretendard/tree/v1.3.9/packages/pretendard/dist/public/static
- https://github.com/orioncactus/pretendard/blob/v1.3.9/LICENSE

Pretendard Medium (500): `d39e50e4bb52b4993b6a4eeb821a171254745bd824446af01e1f616b89fface0`

Pretendard SemiBold (600): `c89bc43027dc7cde5726e96223376f8eec09302b2fc1f8147fd5b57cfc376118`

The complete SIL Open Font License 1.1 and copyright notice are in `Pretendard-LICENSE.txt`. Files are bundled for offline rendering, not loaded from a CDN. No system font fallback is used. The older bundled Noto asset and its license are retained for the historical UI baseline.

Rendering comparison: the earlier UI used Noto Sans CJK KR Regular (400), one global dark outline, and additional health-bar shadow copies. This iteration tests Medium body text, SemiBold headings, no global outline, dark-backed action names, and the existing hinted rasterizer. Godot's official documentation notes that MSDF loses hinting and can be less clear at small sizes, so this pass does not switch to MSDF merely to claim a sharper font. Actual Android before/after frames determine acceptance.

Reference: https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html
