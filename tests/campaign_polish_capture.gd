extends "res://tests/p04_p05_capture.gd"

func redraw() -> void:
	if game.world.has_meta("molten_art"):
		for child in game.world.get_node("LocationArt").get_children():
			if child.has_method("_process"): child._process(0)
		game.world.get_node("LocationArt").queue_redraw()
	else: super.redraw()

func run() -> void:
	destination="res://reports/evidence/campaign-polish/"
	level_ids=["1-1","1-2","1-3","2-1","2-2","2-3","3-1","3-2","3-3"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_ids=[arg.trim_prefix("--level=")]
			destination="res://reports/evidence/campaign-polish/latest/"
	await super.run()
