class_name ExampleLogicTest
extends GdUnitTestSuite

func _clamp_percent(value: float) -> float:
	return clampf(value, 0.0, 100.0)

func test_example_logic_clamp_percent_limits_values() -> void:
	# Arrange
	var low_input := -12.5
	var in_range_input := 42.0
	var high_input := 125.0

	# Act
	var low_result := _clamp_percent(low_input)
	var in_range_result := _clamp_percent(in_range_input)
	var high_result := _clamp_percent(high_input)

	# Assert
	assert_float(low_result).is_equal_approx(0.0, 0.001)
	assert_float(in_range_result).is_equal_approx(42.0, 0.001)
	assert_float(high_result).is_equal_approx(100.0, 0.001)
