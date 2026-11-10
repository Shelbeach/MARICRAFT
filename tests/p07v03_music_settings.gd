extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var c=root.get_node("Campaign")
	while not c.access_ready:await process_frame
	var path:=ProjectSettings.globalize_path("user://settings.cfg")
	# This test may only write the explicitly isolated APPDATA supplied by its runner.
	if not path.replace("\\","/").contains("p07v03-music/volume-profile"):
		push_error("Refusing to write a non-test settings path: "+path);quit(1);return
	var sfx_level:int=c.volume("Эффекты")
	c.store_options({"Музыка":40,"Эффекты":sfx_level},{"Музыка":false,"Эффекты":c.muted("Эффекты")})
	var disk:=ConfigFile.new()
	var ok:bool=disk.load(path)==OK and disk.get_value("sound","Музыка")==40
	c.settings=ConfigFile.new();c.settings.load(path);c.apply_audio()
	ok=ok and c.volume("Музыка")==40 and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))-linear_to_db(.4))<.01
	ok=ok and c.volume("Эффекты")==sfx_level
	FileAccess.open("res://reports/evidence/p07v03-music/settings-persistence.json",FileAccess.WRITE).store_string(JSON.stringify({"path":path,"value":c.volume("Музыка"),"passed":ok,"ordinary_profile_touched":false},"  "))
	print("SETTINGS SAVE/READ/APPLY ",ok)
	root.get_node("MusicManager").stop_all()
	OS.delay_msec(150)
	quit(0 if ok else 1)
