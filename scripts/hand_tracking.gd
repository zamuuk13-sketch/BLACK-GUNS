extends RefCounted
class_name BlackGunsHandTracking
const PLUGIN_NAME := "BlackGunsHandTracking"
var plugin = null
var available := false
var initialized := false
var last_result := {"left": [], "right": [], "hands": 0, "timestamp_us": 0, "confidence": 0.0}
func _init() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		plugin = Engine.get_singleton(PLUGIN_NAME)
		available = true
		initialized = bool(plugin.initialize())
func is_available() -> bool:
	return available and initialized
func process_rgb_frame(rgb: PackedByteArray, width: int, height: int, timestamp_us: int) -> Dictionary:
	if not is_available(): return last_result
	var parsed = JSON.parse_string(str(plugin.processFrame(rgb, width, height, timestamp_us)))
	if parsed is Dictionary: last_result = parsed
	return last_result
func close() -> void:
	if is_available(): plugin.close()
	initialized = false
