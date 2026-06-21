# GdUnit4 test runner compatibility shim.
# Prefer: godot --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit res://tests/integration
extends SceneTree

func _init() -> void:
	push_error("Use the GdUnit4 command runner directly: res://addons/gdUnit4/bin/GdUnitCmdTool.gd")
	quit(1)
