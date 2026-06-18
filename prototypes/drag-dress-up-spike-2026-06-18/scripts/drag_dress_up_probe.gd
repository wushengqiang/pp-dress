# PROTOTYPE - NOT FOR PRODUCTION
# Question: Can Godot 4.6 Web provide a responsive mouse/touch dress-up drag interaction with forgiving hotzone drops and an equivalent click-to-apply path?
# Date: 2026-06-18
extends Control

const HOTZONE_PADDING_PX := 48.0
const CARD_SIZE := Vector2(132, 78)
const SUCCESS_FLASH_TIME := 0.22
const INVALID_FLASH_TIME := 0.16

var _items := [
	{"id": "top_cardigan", "label": "Top", "color": Color(0.96, 0.58, 0.55)},
	{"id": "bottom_skirt", "label": "Bottom", "color": Color(0.56, 0.72, 0.96)},
	{"id": "shoes_canvas", "label": "Shoes", "color": Color(0.88, 0.75, 0.48)},
	{"id": "hair_ribbon", "label": "Hair", "color": Color(0.74, 0.58, 0.92)}
]

var _card_rects: Dictionary = {}
var _equipped: Dictionary = {}
var _selected_item := ""
var _drag_item := ""
var _drag_offset := Vector2.ZERO
var _drag_position := Vector2.ZERO
var _drag_start_msec := 0
var _drag_samples := 0
var _last_pointer_position := Vector2.ZERO
var _success_count := 0
var _invalid_count := 0
var _click_apply_count := 0
var _flash_color := Color.TRANSPARENT
var _flash_time_left := 0.0
var _log_lines: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rebuild_layout()
	_log("DRAG SPIKE READY")
	_log("Drag a card onto the character, or click a card then click the character.")
	_log("For Web, serve over HTTP and keep the pointer inside the canvas.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild_layout()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_pointer_button(event.position, event.pressed, event.button_index == MOUSE_BUTTON_LEFT)
	elif event is InputEventScreenTouch:
		_handle_pointer_button(event.position, event.pressed, true)
	elif event is InputEventMouseMotion:
		_handle_pointer_motion(event.position)
	elif event is InputEventScreenDrag:
		_handle_pointer_motion(event.position)

func _process(delta: float) -> void:
	if _flash_time_left > 0.0:
		_flash_time_left = maxf(0.0, _flash_time_left - delta)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.10))
	_draw_title()
	_draw_cards()
	_draw_character()
	_draw_drag_preview()
	_draw_status_panel()

func _rebuild_layout() -> void:
	_card_rects.clear()
	var start := Vector2(28, 96)
	for i in _items.size():
		var item: Dictionary = _items[i]
		_card_rects[item["id"]] = Rect2(start + Vector2(0, i * 96), CARD_SIZE)
	queue_redraw()

func _handle_pointer_button(position: Vector2, pressed: bool, primary: bool) -> void:
	if not primary:
		return
	_last_pointer_position = position
	if pressed:
		var item_id := _item_at(position)
		if item_id != "":
			_start_drag(item_id, position)
			_selected_item = item_id
			_log("selected %s" % item_id)
			queue_redraw()
			return
		if _selected_item != "" and _expanded_hotzone().has_point(position):
			_apply_item(_selected_item, "click_apply")
			_click_apply_count += 1
			queue_redraw()
	else:
		if _drag_item != "":
			_finish_drag(position)

func _handle_pointer_motion(position: Vector2) -> void:
	_last_pointer_position = position
	if _drag_item == "":
		return
	_drag_position = position + _drag_offset
	_drag_samples += 1
	queue_redraw()

func _start_drag(item_id: String, position: Vector2) -> void:
	_drag_item = item_id
	_drag_start_msec = Time.get_ticks_msec()
	_drag_samples = 0
	var rect: Rect2 = _card_rects[item_id]
	_drag_offset = rect.position - position
	_drag_position = rect.position
	_log("drag_started %s" % item_id)

func _finish_drag(position: Vector2) -> void:
	var elapsed := Time.get_ticks_msec() - _drag_start_msec
	var item_id := _drag_item
	_drag_item = ""
	if _expanded_hotzone().has_point(position):
		_apply_item(item_id, "drag_drop")
		_log("drag_applied %s in %dms with %d samples" % [item_id, elapsed, _drag_samples])
	else:
		_invalid_count += 1
		_flash(Color(0.80, 0.42, 0.36), INVALID_FLASH_TIME)
		_log("drag_cancelled %s outside hotzone" % item_id)
	queue_redraw()

func _apply_item(item_id: String, source: String) -> void:
	var category := item_id.get_slice("_", 0)
	if _equipped.get(category, "") == item_id:
		_log("same_item %s" % item_id)
		_flash(Color(0.62, 0.64, 0.68), INVALID_FLASH_TIME)
		return
	_equipped[category] = item_id
	_success_count += 1
	_flash(Color(0.42, 0.74, 0.58), SUCCESS_FLASH_TIME)
	_log("outfit_apply_result %s accepted=true source=%s" % [item_id, source])

func _item_at(position: Vector2) -> String:
	for item in _items:
		var item_id: String = item["id"]
		if _card_rects[item_id].has_point(position):
			return item_id
	return ""

func _expanded_hotzone() -> Rect2:
	return _character_rect().grow(HOTZONE_PADDING_PX)

func _character_rect() -> Rect2:
	var w := minf(280.0, size.x * 0.32)
	var h := minf(430.0, size.y * 0.68)
	var x := size.x * 0.55
	var y := maxf(92.0, (size.y - h) * 0.55)
	return Rect2(Vector2(x, y), Vector2(w, h))

func _draw_title() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(28, 42), "Drag Dress-Up Spike", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(28, 70), "Test drag, outside drop, and click-to-apply in editor + Web.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.78, 0.80, 0.84))

func _draw_cards() -> void:
	for item in _items:
		var item_id: String = item["id"]
		var rect: Rect2 = _card_rects[item_id]
		var color: Color = item["color"]
		if item_id == _selected_item:
			draw_rect(rect.grow(4), Color(1.0, 1.0, 1.0, 0.18), true)
		draw_rect(rect, color, true)
		draw_rect(rect, Color(1, 1, 1, 0.35), false, 2)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(14, 32), item["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.08, 0.08, 0.10))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(14, 57), item_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.12, 0.12, 0.14))

func _draw_character() -> void:
	var hotzone := _expanded_hotzone()
	var body := _character_rect()
	var hover := hotzone.has_point(_last_pointer_position)
	var fill := Color(0.22, 0.25, 0.30)
	if hover:
		fill = Color(0.28, 0.34, 0.38)
	if _flash_time_left > 0.0:
		fill = fill.lerp(_flash_color, minf(1.0, _flash_time_left / SUCCESS_FLASH_TIME))
	draw_rect(hotzone, Color(1.0, 1.0, 1.0, 0.055), true)
	draw_rect(body, fill, true)
	draw_rect(body, Color(0.88, 0.88, 0.90), false, 3)
	var head_center := body.position + Vector2(body.size.x * 0.5, 58)
	draw_circle(head_center, 42, Color(0.72, 0.66, 0.62))
	draw_rect(Rect2(body.position + Vector2(body.size.x * 0.25, 108), Vector2(body.size.x * 0.5, body.size.y - 150)), Color(0.52, 0.55, 0.60), true)
	var y := body.position.y + body.size.y - 34
	for category in _equipped.keys():
		draw_string(ThemeDB.fallback_font, Vector2(body.position.x + 20, y), "%s: %s" % [category, _equipped[category]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		y -= 20
	draw_string(ThemeDB.fallback_font, body.position + Vector2(18, 24), "Character hotzone", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw_drag_preview() -> void:
	if _drag_item == "":
		return
	var item := _item_by_id(_drag_item)
	var rect := Rect2(_drag_position, CARD_SIZE)
	draw_rect(rect, item["color"].lightened(0.12), true)
	draw_rect(rect, Color.WHITE, false, 2)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(14, 34), item["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.08, 0.08, 0.10))

func _draw_status_panel() -> void:
	var panel := Rect2(Vector2(size.x - 310, 28), Vector2(282, 190))
	draw_rect(panel, Color(0.02, 0.02, 0.025, 0.82), true)
	draw_rect(panel, Color(1, 1, 1, 0.18), false, 1)
	var lines := [
		"success: %d" % _success_count,
		"invalid drops: %d" % _invalid_count,
		"click applies: %d" % _click_apply_count,
		"selected: %s" % (_selected_item if _selected_item != "" else "none"),
		"dragging: %s" % (_drag_item if _drag_item != "" else "none")
	]
	for i in lines.size():
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(14, 28 + i * 22), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.88, 0.90, 0.92))
	var log_y := panel.position.y + 145
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 14, log_y), "latest:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.68, 0.70, 0.74))
	if not _log_lines.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 14, log_y + 22), _log_lines[-1], HORIZONTAL_ALIGNMENT_LEFT, 250, 12, Color(0.88, 0.90, 0.92))

func _item_by_id(item_id: String) -> Dictionary:
	for item in _items:
		if item["id"] == item_id:
			return item
	return _items[0]

func _flash(color: Color, duration: float) -> void:
	_flash_color = color
	_flash_time_left = duration

func _log(message: String) -> void:
	print(message)
	_log_lines.append(message)
	if _log_lines.size() > 8:
		_log_lines.pop_front()

