extends SceneTree
const PATHS=["res://assets/forest_art/characters/sprites/human_small/human_small.tres","res://assets/forest_art/gameplay/items/items.tres","res://assets/molten_art/effects/boss_eruption/boss_eruption.tres"]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var accepted:bool="--accepted" in OS.get_cmdline_user_args()
	var result:Dictionary={}
	for path in PATHS:
		var frames:SpriteFrames=ResourceLoader.load(path,"SpriteFrames",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var clips:Dictionary={}
		for clip in frames.get_animation_names():
			var cells:Array=[]
			for i in frames.get_frame_count(clip):
				var texture=frames.get_frame_texture(clip,i)
				cells.append({"texture":texture.atlas.resource_path,"region":str(texture.region),"duration":frames.get_frame_duration(clip,i),"filter_clip":texture.filter_clip})
			clips[clip]={"speed":frames.get_animation_speed(clip),"loop":frames.get_animation_loop(clip),"cells":cells}
		result[path]=clips
	FileAccess.open("D:/Projects/MARICRAFT/reports/evidence/camera-repair/animations-"+("accepted" if accepted else "current")+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("ANIMATION INVENTORY ","accepted" if accepted else "current")
	quit()
