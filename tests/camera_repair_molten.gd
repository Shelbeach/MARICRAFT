extends "res://tests/final_polish_molten.gd"
func _initialize() -> void:
	var metrics=preload("res://tests/camera_repair_metrics.gd").new()
	metrics.set_meta("region","molten")
	root.add_child.call_deferred(metrics)
	super._initialize()
