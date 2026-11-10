extends "res://tests/campaign_polish_molten.gd"
var movie_count:=0
var movie_pending:=false
var movie_folder:=""
func _initialize() -> void:
	root.unfocusable=true
	RenderingServer.frame_post_draw.connect(capture_movie)
	super._initialize()
func next_frame() -> void:
	await super.next_frame()
	if frame_no%4==0:
		movie_pending=true
func capture_movie() -> void:
	if not movie_pending or movie_folder.is_empty(): return
	movie_pending=false
	var img:=root.get_texture().get_image()
	img.resize(640,360,Image.INTERPOLATE_LANCZOS)
	img.save_png(movie_folder+"%05d.png"%movie_count)
	movie_count+=1
func start_stage(n:String) -> void:
	movie_count=0
	movie_pending=false
	movie_folder="res://reports/temp/campaign-polish/continuous/"+n+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(movie_folder))
	super.start_stage(n)
