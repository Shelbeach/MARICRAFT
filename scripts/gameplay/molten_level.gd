extends "res://scripts/gameplay/forest_level.gd"
## Shared session, checkpoint, rewards and pipes; only chapter-specific presentation.
@export var chapter_level := "3-1"

func _ready() -> void:
	super._ready()
	# Existing actor adapters share their effect provider with the Durotar adapter.
	# Set this after the shared setup: P06 scenery is not installed in this chapter.
	set_meta("location2_art",true)
	set_meta("molten_art",true)
	var art:=preload("res://scripts/visual/molten_art.gd").new()
	art.name="LocationArt"
	add_child(art)

func _draw() -> void:
	pass
