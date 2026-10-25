# Engine choice

This project uses the already installed **Godot 4.6.3 standard**, GDScript and the native 2D **Compatibility** renderer. The fit is a small offline Android game with direct APK export, a lightweight source project and an authoritative model that can run in real Godot headless tests without rendering. No engine upgrade was needed to implement the supplied solo design.

Unity is also a viable engine, but for this new small 2D project it adds setup and licensing administration without an identified requirement that outweighs the existing Godot toolchain. A JavaScript game with a WebView wrapper can produce an Android app, but adds a browser/wrapper layer when there is no existing web game to preserve. These are project-fit judgments, not measured performance benchmarks or claims that the alternatives cannot work.

Official references:
- Godot 4.6 Android export: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html
- Godot renderer guidance: https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html
- Matching Godot 4.6.3 binaries/templates: https://godotengine.org/download/archive/4.6.3-stable/
- Godot license: https://godotengine.org/license/

## Emulator evidence and compatibility limits

The initial Android 35 software-emulator run using legacy SwiftShader GLES failed to link both SceneShaderGLES3 and CanvasShaderGLES3 with a 261-fragment-uniform limit error. Screenshots from that attempt show a system launcher ANR, not successful game rendering. Native logic/UI tests and successful APK export do not establish an Android pixel pass.

The same frozen 5aa3 normal APK subsequently rendered its actual title/hero-selection scene on the official Android API 30 emulator with ANGLE (2026-10-24 18:13 UTC), without the earlier shader-link error in the captured log. That is a first-scene rendering pass, not yet a full match, lifecycle or performance pass. The investigation uses officially supported emulator/API/ANGLE driver combinations with immutable APKs. No engine/template patch, security weakening, speculative renderer-setting workaround or automatic engine upgrade is part of this build. A later immutable c86ee7c debug QA variant completed an uninterrupted rendered guardian match on that API 30 + ANGLE emulator on 2026-10-24: Victory after 447.73 simulation seconds and 2463.43 wall seconds. This resolves a full-flow Android rendering/runtime gate for that visibly labeled synthetic-input QA variant, not representative phone performance or an exact-normal-binary full match. The separately installed normal APK has its own OS-input/lifecycle evidence. The final QA report identifies the exact artifact hashes and driver tested; later presentation revisions do not automatically inherit exact-binary acceptance. Physical-phone performance and touch feel remain separate from emulator evidence.


## Original startup artwork

The later 0.2 source candidate replaces the default engine splash with the existing original crystal-fortress PNG, using aspect-preserving `boot_splash/stretch_mode=1` and no artificial minimum display delay. Godot attribution remains in credits and bundled licenses. These settings follow the [Godot 4.6 ProjectSettings reference](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-application-boot-splash-image) and [SplashStretchMode reference](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html#enum-renderingserver-splashstretchmode). The customized splash still needs visual verification in its exact exported APK.
