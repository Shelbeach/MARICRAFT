extends "res://tests/final_polish_forest.gd"
func _initialize() -> void:
	var metrics=preload("res://tests/camera_repair_metrics.gd").new()
	metrics.set_meta("region","forest")
	root.add_child.call_deferred(metrics)
	super._initialize()
