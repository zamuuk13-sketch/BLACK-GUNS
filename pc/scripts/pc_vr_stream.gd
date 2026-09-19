extends Node
class_name BlackGunsVRStream

signal stream_status_changed(message: String)

@export var stream_width := 640
@export var stream_height := 360
@export var stream_fps := 20.0
@export_range(20, 90, 1) var jpeg_quality := 45
@export var video_port := 39102
@export var udp_chunk_size := 1200
@export var udp_enabled := true

var left_viewport: SubViewport
var right_viewport: SubViewport
var left_camera: Camera3D
var right_camera: Camera3D
var source_camera: Camera3D

var destination_ip := ""
var frame_id := 0
var accumulator := 0.0
var running := false
var last_frame_time_us := 0

func _ready() -> void:
    source_camera = get_node_or_null("../PCEnvironment/PlayerCamera")
    if source_camera == null:
        source_camera = get_node_or_null("../PlayerCamera")
    _build_capture()
    set_process(true)

func start_stream(target_ip: String) -> void:
    destination_ip = target_ip.strip_edges()
    running = not destination_ip.is_empty()
    stream_status_changed.emit("VR stream: %s" % ("ativo → %s:%d" % [destination_ip, video_port] if running else "aguardando celular"))

func stop_stream() -> void:
    running = false
    stream_status_changed.emit("VR stream parado")

func set_target_ip(ip: String) -> void:
    destination_ip = ip.strip_edges()

func _build_capture() -> void:
    left_viewport = _make_viewport()
    right_viewport = _make_viewport()
    left_camera = _make_camera(left_viewport, "StreamLeftEye")
    right_camera = _make_camera(right_viewport, "StreamRightEye")

func _make_viewport() -> SubViewport:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(stream_width, stream_height)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    viewport.msaa_3d = Viewport.MSAA_DISABLED
    viewport.world_3d = get_viewport().world_3d
    add_child(viewport)
    return viewport

func _make_camera(viewport: SubViewport, camera_name: String) -> Camera3D:
    var camera := Camera3D.new()
    camera.name = camera_name
    camera.current = true
    camera.fov = 90.0
    camera.near = 0.03
    camera.far = 500.0
    viewport.add_child(camera)
    return camera

func _process(delta: float) -> void:
    if not running or destination_ip.is_empty():
        return
    if not is_instance_valid(source_camera):
        return

    accumulator += delta
    var interval := 1.0 / max(stream_fps, 1.0)
    if accumulator < interval:
        return
    accumulator = fmod(accumulator, interval)

    _update_eye_cameras()
    await get_tree().process_frame
    _send_eye_frame(0, left_viewport.get_texture().get_image())
    _send_eye_frame(1, right_viewport.get_texture().get_image())

func _update_eye_cameras() -> void:
    var center := source_camera.global_transform
    var half_ipd := 0.064 * 0.5
    var right_axis := center.basis.x.normalized()

    left_camera.global_transform = center
    left_camera.global_transform.origin -= right_axis * half_ipd
    right_camera.global_transform = center
    right_camera.global_transform.origin += right_axis * half_ipd

func _send_eye_frame(eye: int, image: Image) -> void:
    if image == null or image.is_empty():
        return

    var jpeg := image.save_jpg_to_buffer(float(jpeg_quality) / 100.0)
    if jpeg.is_empty():
        return

    frame_id += 1
    last_frame_time_us = Time.get_ticks_usec()

    if udp_enabled:
        _send_udp_chunks(eye, frame_id, jpeg)
    stream_status_changed.emit("VR stream ativo • frame %d • L/R %d bytes" % [frame_id, jpeg.size()])

func _send_udp_chunks(eye: int, id: int, data: PackedByteArray) -> void:
    var socket := PacketPeerUDP.new()
    var err := socket.set_dest_address(destination_ip, video_port)
    if err != OK:
        return

    var total := int(ceil(float(data.size()) / float(udp_chunk_size)))
    for chunk_index in total:
        var start := chunk_index * udp_chunk_size
        var length := min(udp_chunk_size, data.size() - start)
        var payload := data.slice(start, start + length)
        var header := PackedByteArray()
        header.append_array("BGVR".to_utf8_buffer())
        header.append(1)
        header.append(eye)
        header.append_array(_u32(id))
        header.append_array(_u16(chunk_index))
        header.append_array(_u16(total))
        header.append_array(_u32(data.size()))
        header.append_array(payload)
        socket.put_packet(header)
    socket.close()

func _u16(value: int) -> PackedByteArray:
    return PackedByteArray([value & 255, (value >> 8) & 255])

func _u32(value: int) -> PackedByteArray:
    return PackedByteArray([
        value & 255,
        (value >> 8) & 255,
        (value >> 16) & 255,
        (value >> 24) & 255
    ])
