extends "res://tests/p04_p05_capture.gd"

func redraw() -> void:
	if game.world.has_meta("molten_art"):
		for child in game.world.get_node("LocationArt").get_children():
			if child.has_method("_process"): child._process(0)
		game.world.get_node("LocationArt").queue_redraw()
	else: super.redraw()

func run() -> void:
	destination="res://reports/evidence/p07v03-music/"
	level_ids=["3-1","3-2","3-3"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_ids=[arg.trim_prefix("--level=")]
			destination="res://reports/evidence/p07v03-music/latest/"
	await super.run()
