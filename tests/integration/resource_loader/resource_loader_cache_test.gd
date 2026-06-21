class_name ResourceLoaderCacheTest
extends GdUnitTestSuite

const FULL := 1
const THUMB := 0
const MAX_HOT_FULL := 8
const MAX_WARM_FULL := 4
const MIPMAP_FACTOR := 1.33
const FULL_SIZE := Vector2i(1024, 1536)
const THUMB_SIZE := Vector2i(48, 48)
const ITEM_COUNT := 14
const ASSET_DIR := "user://resource_loader_spike"

var _hot_cache: Dictionary = {}
var _warm_cache: Dictionary = {}
var _reported_missing_engine_cache_release := false
var _warning_messages: Array[String] = []
var _frame := 0

func test_resource_loader_evict_full_textures_preserves_thumbs() -> void:
	# Arrange
	_insert_hot("item_12", THUMB, _make_texture(THUMB_SIZE))
	_insert_hot("item_13", FULL, _make_texture(FULL_SIZE))

	# Act
	evict_full_textures()

	# Assert
	assert_bool(is_cached("item_13", FULL)).is_false()
	assert_bool(is_cached("item_12", THUMB)).is_true()
	assert_int(_warning_messages.size()).is_equal(1)
	assert_str(_warning_messages[0]).contains("remove_resource_from_cache")

func test_resource_loader_memory_estimate_stays_under_web_budget() -> void:
	# Arrange
	_hot_cache.clear()
	_warm_cache.clear()
	for i in 8:
		_insert_hot(_item_id(i), FULL, _make_texture(FULL_SIZE))
	for i in range(8, 12):
		_warm_cache[_key(_item_id(i), FULL)] = {
			"texture": _make_texture(FULL_SIZE),
			"path": _path_for(_item_id(i), FULL),
			"last_access": _frame
		}
	for i in ITEM_COUNT:
		_insert_hot(_item_id(i), THUMB, _make_texture(THUMB_SIZE))

	# Act
	var estimate := get_memory_estimate()

	# Assert
	assert_int(estimate).is_less(256 * 1024 * 1024)

func test_resource_loader_path_builder_matches_full_and_thumb_suffixes() -> void:
	# Arrange
	var item_id := "item_03"

	# Act
	var full_path := _path_for(item_id, FULL)
	var thumb_path := _path_for(item_id, THUMB)

	# Assert
	assert_str(full_path).is_equal("user://resource_loader_spike/item_03_full.tres")
	assert_str(thumb_path).is_equal("user://resource_loader_spike/item_03_thumb.tres")

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
		_release_engine_cache_if_supported(_warm_cache[oldest_key]["path"])
		_warm_cache.erase(oldest_key)

func evict_full_textures() -> void:
	for key in _hot_cache.keys():
		if key.ends_with(":%d" % FULL):
			_release_engine_cache_if_supported(_hot_cache[key]["path"])
			_hot_cache.erase(key)
	for key in _warm_cache.keys():
		if key.ends_with(":%d" % FULL):
			_release_engine_cache_if_supported(_warm_cache[key]["path"])
			_warm_cache.erase(key)

func is_cached(item_id: String, resolution: int) -> bool:
	var key := _key(item_id, resolution)
	return _hot_cache.has(key) or _warm_cache.has(key)

func get_memory_estimate() -> int:
	var bytes := 0
	for entry in _hot_cache.values():
		bytes += _estimate_entry(entry["texture"])
	for entry in _warm_cache.values():
		bytes += _estimate_entry(entry["texture"])
	return int(round(bytes * MIPMAP_FACTOR))

func _release_engine_cache_if_supported(path: String) -> void:
	if not _reported_missing_engine_cache_release:
		_reported_missing_engine_cache_release = true
		_warn("ResourceLoader has no remove_resource_from_cache() API in Godot 4.6; first affected path: %s" % path)

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

func _make_texture(size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func _warn(message: String) -> void:
	_warning_messages.append(message)
