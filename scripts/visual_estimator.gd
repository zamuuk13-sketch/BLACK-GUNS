extends RefCounted
class_name BlackGunsVisualEstimator

# Etapa 4: estimador visual leve para câmera monocular.
# Ele não inventa escala métrica: estima movimento relativo da imagem
# por block matching e fornece qualidade/confiança para a fusão com IMU.

const GRID_X := 8
const GRID_Y := 5
const PATCH_RADIUS := 2
const SEARCH_RADIUS := 5
const MIN_CONTRAST := 18.0
const MAX_MEAN_ERROR := 42.0
const MIN_TRACKS := 5
const SAMPLE_WIDTH := 160
const SAMPLE_HEIGHT := 90

var previous_gray: PackedFloat32Array = PackedFloat32Array()
var current_gray: PackedFloat32Array = PackedFloat32Array()
var frame_width := 0
var frame_height := 0

var initialized := false
var last_dx := 0.0
var last_dy := 0.0
var last_confidence := 0.0
var tracked_points := 0
var sample_count := 0
var timestamp_us := 0

func reset() -> void:
	previous_gray = PackedFloat32Array()
	current_gray = PackedFloat32Array()
	initialized = false
	last_dx = 0.0
	last_dy = 0.0
	last_confidence = 0.0
	tracked_points = 0
	sample_count = 0
	timestamp_us = 0

func process_texture(texture: Texture2D) -> Dictionary:
	if texture == null:
		return _result(false)

	var image := texture.get_image()
	if image == null or image.is_empty():
		return _result(false)

	image.convert(Image.FORMAT_L8)
	image.resize(SAMPLE_WIDTH, SAMPLE_HEIGHT, Image.INTERPOLATE_BILINEAR)
	var data := image.get_data()
	if data.is_empty():
		return _result(false)

	current_gray.resize(SAMPLE_WIDTH * SAMPLE_HEIGHT)
	for i in current_gray.size():
		current_gray[i] = float(data[i])

	frame_width = SAMPLE_WIDTH
	frame_height = SAMPLE_HEIGHT
	sample_count += 1
	timestamp_us = Time.get_ticks_usec()

	if not initialized:
		previous_gray = current_gray.duplicate()
		initialized = true
		return _result(false)

	var motions: Array[Vector2] = []
	var errors: Array[float] = []

	for gy in GRID_Y:
		var y := int(8 + gy * float(SAMPLE_HEIGHT - 16) / float(GRID_Y - 1))
		for gx in GRID_X:
			var x := int(8 + gx * float(SAMPLE_WIDTH - 16) / float(GRID_X - 1))
			var track := _track_patch(previous_gray, current_gray, x, y)
			if track.valid:
				motions.append(track.motion)
				errors.append(track.error)

	if motions.size() >= MIN_TRACKS:
		var median_motion := _median_vector(motions)
		var median_error := _median(errors)
		last_dx = median_motion.x
		last_dy = median_motion.y
		tracked_points = motions.size()
		last_confidence = clamp(float(motions.size()) / float(GRID_X * GRID_Y), 0.0, 1.0)
		last_confidence *= clamp(1.0 - median_error / MAX_MEAN_ERROR, 0.0, 1.0)
	else:
		last_dx = 0.0
		last_dy = 0.0
		tracked_points = motions.size()
		last_confidence = 0.0

	previous_gray = current_gray.duplicate()
	return _result(last_confidence > 0.15)

func _track_patch(old_img: PackedFloat32Array, new_img: PackedFloat32Array, x: int, y: int) -> Dictionary:
	var center := _pixel(old_img, x, y)
	var contrast := 0.0
	for oy in range(-PATCH_RADIUS, PATCH_RADIUS + 1):
		for ox in range(-PATCH_RADIUS, PATCH_RADIUS + 1):
			contrast += abs(_pixel(old_img, x + ox, y + oy) - center)
	contrast /= float((PATCH_RADIUS * 2 + 1) * (PATCH_RADIUS * 2 + 1))
	if contrast < MIN_CONTRAST:
		return {"valid": false, "motion": Vector2.ZERO, "error": 999.0}

	var best_error := INF
	var best_motion := Vector2.ZERO

	for dy in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
		for dx in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
			var nx := x + dx
			var ny := y + dy
			if nx - PATCH_RADIUS < 0 or nx + PATCH_RADIUS >= SAMPLE_WIDTH:
				continue
			if ny - PATCH_RADIUS < 0 or ny + PATCH_RADIUS >= SAMPLE_HEIGHT:
				continue

			var error := 0.0
			for oy in range(-PATCH_RADIUS, PATCH_RADIUS + 1):
				for ox in range(-PATCH_RADIUS, PATCH_RADIUS + 1):
					error += abs(_pixel(old_img, x + ox, y + oy) - _pixel(new_img, nx + ox, ny + oy))
			error /= float((PATCH_RADIUS * 2 + 1) * (PATCH_RADIUS * 2 + 1))

			if error < best_error:
				best_error = error
				best_motion = Vector2(dx, dy)

	return {"valid": best_error <= MAX_MEAN_ERROR, "motion": best_motion, "error": best_error}

func _pixel(img: PackedFloat32Array, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= SAMPLE_WIDTH or y >= SAMPLE_HEIGHT:
		return 0.0
	return img[y * SAMPLE_WIDTH + x]

func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[int(sorted.size() / 2)])

func _median_vector(values: Array[Vector2]) -> Vector2:
	var xs: Array = []
	var ys: Array = []
	for value in values:
		xs.append(value.x)
		ys.append(value.y)
	return Vector2(_median(xs), _median(ys))

func _result(valid: bool) -> Dictionary:
	return {
		"valid": valid,
		"dx": last_dx,
		"dy": last_dy,
		"confidence": last_confidence,
		"tracked_points": tracked_points,
		"sample_count": sample_count,
		"timestamp_us": timestamp_us
	}
