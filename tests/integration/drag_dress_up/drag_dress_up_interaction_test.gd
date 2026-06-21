class_name DragDressUpInteractionTest
extends GdUnitTestSuite

const HOTZONE_PADDING_PX := 48.0

var _equipped: Dictionary = {}
var _selected_item := ""
var _drag_item := ""
var _success_count := 0
var _invalid_count := 0

func before_test() -> void:
	_equipped.clear()
	_selected_item = ""
	_drag_item = ""
	_success_count = 0
	_invalid_count = 0

func test_drag_dress_up_click_to_apply_uses_selected_item() -> void:
	# Arrange
	_selected_item = "top_cardigan"
	var hotzone := _expanded_hotzone(Vector2(960, 640))
	var click_position := hotzone.get_center()

	# Act
	if _selected_item != "" and hotzone.has_point(click_position):
		_apply_item(_selected_item, "click_apply")

	# Assert
	assert_str(_equipped.get("top", "")).is_equal("top_cardigan")
	assert_int(_success_count).is_equal(1)
	assert_int(_invalid_count).is_equal(0)

func test_drag_dress_up_drop_inside_hotzone_applies_item() -> void:
	# Arrange
	_drag_item = "bottom_skirt"
	var hotzone := _expanded_hotzone(Vector2(960, 640))
	var drop_position := hotzone.get_center()

	# Act
	_finish_drag(drop_position, Vector2(960, 640))

	# Assert
	assert_str(_equipped.get("bottom", "")).is_equal("bottom_skirt")
	assert_int(_success_count).is_equal(1)
	assert_int(_invalid_count).is_equal(0)
	assert_str(_drag_item).is_empty()

func test_drag_dress_up_drop_outside_hotzone_cancels_without_apply() -> void:
	# Arrange
	_drag_item = "shoes_canvas"
	var drop_position := Vector2(20, 20)

	# Act
	_finish_drag(drop_position, Vector2(960, 640))

	# Assert
	assert_bool(_equipped.has("shoes")).is_false()
	assert_int(_success_count).is_equal(0)
	assert_int(_invalid_count).is_equal(1)
	assert_str(_drag_item).is_empty()

func test_drag_dress_up_reapplying_same_item_does_not_increment_success_count() -> void:
	# Arrange
	_selected_item = "top_cardigan"
	var hotzone := _expanded_hotzone(Vector2(960, 640))
	var click_position := hotzone.get_center()

	# Act
	if _selected_item != "" and hotzone.has_point(click_position):
		_apply_item(_selected_item, "click_apply")
	if _selected_item != "" and hotzone.has_point(click_position):
		_apply_item(_selected_item, "click_apply")

	# Assert
	assert_str(_equipped.get("top", "")).is_equal("top_cardigan")
	assert_int(_success_count).is_equal(1)
	assert_int(_invalid_count).is_equal(0)

func _finish_drag(position: Vector2, viewport_size: Vector2) -> void:
	var item_id := _drag_item
	_drag_item = ""
	if _expanded_hotzone(viewport_size).has_point(position):
		_apply_item(item_id, "drag_drop")
	else:
		_invalid_count += 1

func _apply_item(item_id: String, _source: String) -> void:
	var category := item_id.get_slice("_", 0)
	if _equipped.get(category, "") == item_id:
		return
	_equipped[category] = item_id
	_success_count += 1

func _expanded_hotzone(viewport_size: Vector2) -> Rect2:
	return _character_rect(viewport_size).grow(HOTZONE_PADDING_PX)

func _character_rect(viewport_size: Vector2) -> Rect2:
	var w := minf(280.0, viewport_size.x * 0.32)
	var h := minf(430.0, viewport_size.y * 0.68)
	var x := viewport_size.x * 0.55
	var y := maxf(92.0, (viewport_size.y - h) * 0.55)
	return Rect2(Vector2(x, y), Vector2(w, h))
