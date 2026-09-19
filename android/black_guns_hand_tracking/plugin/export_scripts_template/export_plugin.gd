@tool
extends EditorExportPlugin

const _plugin_name := "BlackGunsHandTracking"

func _get_name() -> String:
    return _plugin_name

func _supports_platform(platform: EditorExportPlatform) -> bool:
    return platform is EditorExportPlatformAndroid

func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
    if debug:
        return PackedStringArray(["BlackGunsHandTracking/bin/debug/BlackGunsHandTracking-debug.aar"])
    return PackedStringArray(["BlackGunsHandTracking/bin/release/BlackGunsHandTracking-release.aar"])

func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
    return PackedStringArray(["com.google.mediapipe:tasks-vision:0.10.26"])
