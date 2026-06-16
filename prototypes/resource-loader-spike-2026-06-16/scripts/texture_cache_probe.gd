# PROTOTYPE - NOT FOR PRODUCTION
# Question: Can Godot 4.6 validate the Resource Loader GDD assumptions for threaded texture loading, cache eviction, and memory estimates before production implementation?
# Date: 2026-06-16
extends Control

const THUMB := 0
const FULL := 1
const MAX_HOT_FULL := 8
const MAX_WARM_FULL := 4
const MIPMAP_FACTOR := 1.33
const FULL_SIZE := Vector2i(1024, 1536)
const THUMB_SIZE := Vector2i(48, 48)
const ITEM_COUNT := 14
const ASSET_DIR := "user://resource_loader_spike"

var _label: RichTextLabel
var _hot_cache: Dictionary = {}
var _warm_cache: Dictionary = {}
var _pending_requests: Dictionary = {}
var _load_start_count: Dictionary = {}
var _loaded_callbacks: Dictionary = {}
var _errors: Array[String] = []
var _steps: Array[Callable] = []
var _step_index := 0
var _frame := 0

func _ready() -> void:
	_build_ui()
	_log("Resource Loader spike starting.")
	_log("Engine version: %s" % Engine.get_version_info().get("string", "unknown"))
	_prepare_probe_assets()
	_steps = [
		_test_threaded_request,
		_test_duplicate_request_dedup,
		_test_hot_warm_lru,
		_test_evict_full_textures,
		_test_memory_estimate,
		_finish
	]
	set_process(true)

func _process(_delta: float) -> void:
	_frame += 1
	_poll_pending_requests()
	if _pending_requests.is_empty() and _step_index < _steps.size():
		var step := _steps[_step_index]
		_step_index += 1
		step.call()

func _build_ui() -> void:
	_label = RichTextLabel.new()
	_label.fit_content = true
	_label.scroll_active = true
	_label.bbcode_enabled = false
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("normal_font_size", 15)
	add_child(_label)

func _prepare_probe_assets() -> void:
	DirAccess.make_dir_recursive_absolute(ASSET_DIR)
	for i in ITEM_COUNT:
		_save_texture_resource(_item_id(i), FULL, FULL_SIZE, Color.from_hsv(float(i) / ITEM_COUNT, 0.55, 0.92))
		_save_texture_resource(_item_id(i), THUMB, THUMB_SIZE, Color.from_hsv(float(i) / ITEM_COUNT, 0.35, 0.95))
	_log("Generated %d probe items in %s." % [ITEM_COUNT, ASSET_DIR])

func _save_texture_resource(item_id: String, resolution: int, size: Vector2i, color: Color) -> void:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	var err := ResourceSaver.save(texture, _path_for(item_id, resolution))
	if err != OK:
		_fail("ResourceSaver failed for %s with error %s." % [_path_for(item_id, resolution), err])

func _test_threaded_request() -> void:
	_log("")
	_log("TEST 1: threaded request completes and writes HOT.")
	get_texture_or_request("item_00", FULL, func(texture: Texture2D) -> void:
		_record_callback("item_00", texture)
		_assert(texture != null, "item_00 FULL callback returned texture")
		_assert(is_cached("item_00", FULL), "item_00 FULL is cached")
	)

func _test_duplicate_request_dedup() -> void:
	_log("")
	_log("TEST 2: duplicate request dedupes pending load.")
	_loaded_callbacks["item_01"] = 0
	get_texture_or_request("item_01", FULL, func(texture: Texture2D) -> void:
		_record_callback("item_01", texture)
	)
	get_texture_or_request("item_01", FULL, func(texture: Texture2D) -> void:
		_record_callback("item_01", texture)
	)
	await get_tree().process_frame
	while _pending_requests.has(_key("item_01", FULL)):
		await get_tree().process_frame
	_assert(_load_start_count.get(_key("item_01", FULL), 0) == 1, "duplicate request started one threaded load")
	_assert(_loaded_callbacks.get("item_01", 0) == 2, "duplicate request notified both callbacks")

func _test_hot_warm_lru() -> void:
	_log("")
	_log("TEST 3: HOT overflow demotes least-recent FULL to WARM, then promotes it.")
	for i in range(2, 11):
		_insert_hot(_item_id(i), FULL, load(_path_for(_item_id(i), FULL)))
	var demoted_id := "item_02"
	_assert(_warm_cache.has(_key(demoted_id, FULL)), "oldest FULL moved to WARM")
	var texture := get_texture(demoted_id, FULL)
	_assert(texture != null, "WARM promotion returned texture")
	_assert(_hot_cache.has(_key(demoted_id, FULL)), "WARM promotion moved texture to HOT")

func _test_evict_full_textures() -> void:
	_log("")
	_log("TEST 4: evict_full_textures clears FULL only and calls remove_resource_from_cache.")
	_insert_hot("item_12", THUMB, load(_path_for("item_12", THUMB)))
	_insert_hot("item_13", FULL, load(_path_for("item_13", FULL)))
	evict_full_textures()
	_assert(not is_cached("item_13", FULL), "FULL entry removed after eviction")
	_assert(is_cached("item_12", THUMB), "THUMB entry survives FULL eviction")

func _test_memory_estimate() -> void:
	_log("")
	_log("TEST 5: memory estimate matches GDD budget math.")
	_hot_cache.clear()
	_warm_cache.clear()
	for i in 8:
		_insert_hot(_item_id(i), FULL, load(_path_for(_item_id(i), FULL)))
	for i in range(8, 12):
		_warm_cache[_key(_item_id(i), FULL)] = {
			"texture": load(_path_for(_item_id(i), FULL)),
			"path": _path_for(_item_id(i), FULL),
			"last_access": _frame
		}
	for i in ITEM_COUNT:
		_insert_hot(_item_id(i), THUMB, load(_path_for(_item_id(i), THUMB)))
	var estimate := get_memory_estimate()
	_log("Estimated bytes with 8 HOT FULL + 4 WARM FULL + %d THUMB: %d" % [ITEM_COUNT, estimate])
	_assert(estimate < 256 * 1024 * 1024, "default probe budget is below 256MB")

func _finish() -> void:
	_log("")
	if _errors.is_empty():
		_log("SPIKE RESULT: PASS")
		_log("Native/editor API assumptions held. Web export still needs browser run for final P0 validation.")
	else:
		_log("SPIKE RESULT: FAIL")
		for error in _errors:
			_log("ERROR: %s" % error)
	set_process(false)

func get_texture_or_request(item_id: String, resolution: int, callback: Callable) -> void:
	var texture := get_texture(item_id, resolution)
	if texture != null:
		callback.call(texture)
		return
	var key := _key(item_id, resolution)
	if _pending_requests.has(key):
		_pending_requests[key]["callbacks"].append(callback)
		return
	var path := _path_for(item_id, resolution)
	_pending_requests[key] = {
		"item_id": item_id,
		"resolution": resolution,
		"path": path,
		"callbacks": [callback],
		"discarded": false
	}
	_load_start_count[key] = _load_start_count.get(key, 0) + 1
	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		_fail("load_threaded_request failed for %s with error %s." % [path, err])
		_notify_callbacks(key, null)

func get_texture(item_id: String, resolution: int) -> Texture2D:
	var key := _key(item_id, resolution)
	if _hot_cache.has(key):
		_hot_cache[key]["last_access"] = _frame
		return _hot_cache[key]["texture"]
	if _warm_cache.has(key):
		var entry: Dictionary = _warm_cache[key]
		_warm_cache.erase(key)
		_insert_hot(item_id, resolution, entry["texture"])
		return entry["texture"]
	return null

func is_cached(item_id: String, resolution: int) -> bool:
	var key := _key(item_id, resolution)
	return _hot_cache.has(key) or _warm_cache.has(key)

func evict_full_textures() -> void:
	for key in _hot_cache.keys():
		if key.ends_with(":%d" % FULL):
			ResourceLoader.remove_resource_from_cache(_hot_cache[key]["path"])
			_hot_cache.erase(key)
	for key in _warm_cache.keys():
		if key.ends_with(":%d" % FULL):
			ResourceLoader.remove_resource_from_cache(_warm_cache[key]["path"])
			_warm_cache.erase(key)
	for key in _pending_requests.keys():
		if key.ends_with(":%d" % FULL):
			_pending_requests[key]["discarded"] = true

func get_memory_estimate() -> int:
	var bytes := 0
	for entry in _hot_cache.values():
		bytes += _estimate_entry(entry["texture"])
	for entry in _warm_cache.values():
		bytes += _estimate_entry(entry["texture"])
	return int(round(bytes * MIPMAP_FACTOR))

func _poll_pending_requests() -> void:
	for key in _pending_requests.keys():
		var request: Dictionary = _pending_requests[key]
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(request["path"], progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if request["discarded"]:
			_notify_callbacks(key, null)
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var texture := ResourceLoader.load_threaded_get(request["path"])
			_insert_hot(request["item_id"], request["resolution"], texture)
			_notify_callbacks(key, texture)
		else:
			_fail("Threaded load failed for %s with status %s." % [request["path"], status])
			_notify_callbacks(key, null)

func _insert_hot(item_id: String, resolution: int, texture: Texture2D) -> void:
	var key := _key(item_id, resolution)
	_hot_cache[key] = {
		"texture": texture,
		"path": _path_for(item_id, resolution),
		"last_access": _frame
	}
	if resolution == FULL:
		_enforce_hot_limit()

func _enforce_hot_limit() -> void:
	while _count_resolution(_hot_cache, FULL) > MAX_HOT_FULL:
		var oldest_key := _oldest_key(_hot_cache, FULL)
		var entry: Dictionary = _hot_cache[oldest_key]
		_hot_cache.erase(oldest_key)
		_warm_cache[oldest_key] = entry
		_enforce_warm_limit()

func _enforce_warm_limit() -> void:
	while _count_resolution(_warm_cache, FULL) > MAX_WARM_FULL:
		var oldest_key := _oldest_key(_warm_cache, FULL)
		ResourceLoader.remove_resource_from_cache(_warm_cache[oldest_key]["path"])
		_warm_cache.erase(oldest_key)

func _notify_callbacks(key: String, texture: Texture2D) -> void:
	if not _pending_requests.has(key):
		return
	var callbacks: Array = _pending_requests[key]["callbacks"]
	_pending_requests.erase(key)
	for callback in callbacks:
		callback.call(texture)

func _record_callback(item_id: String, texture: Texture2D) -> void:
	_loaded_callbacks[item_id] = _loaded_callbacks.get(item_id, 0) + 1
	_log("Callback for %s: %s" % [item_id, "texture" if texture != null else "null"])

func _estimate_entry(texture: Texture2D) -> int:
	if texture == null:
		return 0
	return texture.get_width() * texture.get_height() * 4

func _count_resolution(cache: Dictionary, resolution: int) -> int:
	var count := 0
	for key in cache.keys():
		if key.ends_with(":%d" % resolution):
			count += 1
	return count

func _oldest_key(cache: Dictionary, resolution: int) -> String:
	var result := ""
	var oldest := 9223372036854775807
	for key in cache.keys():
		if key.ends_with(":%d" % resolution) and cache[key]["last_access"] < oldest:
			oldest = cache[key]["last_access"]
			result = key
	return result

func _item_id(index: int) -> String:
	return "item_%02d" % index

func _key(item_id: String, resolution: int) -> String:
	return "%s:%d" % [item_id, resolution]

func _path_for(item_id: String, resolution: int) -> String:
	var suffix := "full" if resolution == FULL else "thumb"
	return "%s/%s_%s.tres" % [ASSET_DIR, item_id, suffix]

func _assert(condition: bool, message: String) -> void:
	if condition:
		_log("PASS: %s" % message)
	else:
		_fail(message)

func _fail(message: String) -> void:
	_errors.append(message)
	_log("FAIL: %s" % message)

func _log(message: String) -> void:
	print(message)
	if _label != null:
		_label.append_text(message + "\n")

