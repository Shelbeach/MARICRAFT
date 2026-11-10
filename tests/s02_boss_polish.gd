extends "res://tests/s02_forest.gd"

const Pilot:=preload("res://tests/boss_pilot.gd")
var movie:=false
var take:=""
var index:=0
var frames:={}
var photographed:={}
var test_root:="res://reports/evidence/polish/"

func run() -> void:
	movie="--movie" in OS.get_cmdline_user_args()
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/polish/qa-%d"%OS.get_process_id())
	state.p={}
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for kind in ["small","magic","spam"]:
		await fight(kind)
	if movie:
		var f:=FileAccess.open("res://reports/temp/polish/clips.json",FileAccess.WRITE)
		f.store_string(JSON.stringify(frames))
	quit(1 if failed else 0)

func fight(kind: String) -> void:
	await test_level("1-3")
	var w=game.world
	var a=w.player
	var b=w.boss
	var pilot:=Pilot.new()
	await place_player(w.checkpoint_x)
	var ranged:=kind!="small"
	press(KEY_D,true)
	var held:=0
	for i in 180:
		await ticks(1)
		if a.position.x>=1804: break
		if held>0:
			held-=1
			if held==0: press(KEY_SPACE,false)
		elif a.is_on_floor() and (a.is_on_wall() or (ranged and a.position.x>1656 and a.position.x<1680)):
			press(KEY_SPACE,true)
			held=37
	pilot.release(self)
	check(a.form==(2 if ranged else 0),kind+" enters with intended form, actual rune="+str(state.claimed("1-3/arena_rune")))
	take=kind
	index=0
	if movie: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/temp/polish/"+take))
	var last_hp:int=b.hp
	var phases:={}
	var actions:={}
	for i in 4200:
		await physics_frame
		phases[b.phase()]=true
		if b.mode==b.Mode.ACT: actions[b.move.kind]=true
		if b.hp!=last_hp:
			print(kind," HP ",last_hp," -> ",b.hp," at ",a.position)
			check(last_hp-b.hp==(1 if ranged else 3),"accepted hit size")
			if not ranged: check(a.velocity.y<0 and not b.head_armed,"stomp bounces; head must be cleared")
			last_hp=b.hp
		if b.hp==0: break
		await capture(i,b)
		if state.p.hearts<3 or (ranged and a.form!=2): break
		pilot.tick(self,a,b,ranged,kind=="spam")
	pilot.release(self)
	await capture(0,b)
	frames[kind]=index
	print(kind," hp=",b.hp," deflected=",b.deflections," phases=",phases," actions=",actions," actor=",a.position," hearts=",state.p.hearts)
	if kind=="spam":
		check(b.hp>0 and a.form==0 and b.deflections>0,"stationary rapid E loses rune before victory")
	else:
		check(b.hp==0 and phases.size()==3 and actions.size()==3 and state.p.hearts==3,kind+" wins through all attacks")
		check(state.claimed("1-3/chief") and game.page=="play","reward issued, separate exit")
	if kind=="small":
		game.start_level()
		await ticks(5)
		check(game.world.boss.hp==9 and game.world.boss.phase()==1,"restart restores opening phase")
		game.world.boss.take_damage(9)
		check(state.p.score==10000+state.p.coins*10,"no second boss reward")

func capture(i: int,b) -> void:
	if not movie or i%6!=0: return
	await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	if take=="small" and b.mode==b.Mode.WARN and not photographed.has(b.move.kind):
		img.save_png(test_root+"warn-"+str(b.move.kind)+".png")
		photographed[b.move.kind]=true
	if b.mode==b.Mode.OPEN and not photographed.has("open"):
		img.save_png(test_root+"open.png")
		photographed["open"]=true
	img.resize(640,360,Image.INTERPOLATE_BILINEAR)
	img.save_png("res://reports/temp/polish/%s/%04d.png"%[take,index])
	index+=1
