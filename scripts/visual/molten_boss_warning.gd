extends Node2D
## Attack warnings complement the separate P07 v03 body/hammer rig.
var boss
var library
var fire
var waves:Array=[]
func _ready() -> void:
	boss.set_meta("p07_warnings",true)
	fire=library.resource("effects/boss_projectile/boss_projectile.tscn").instantiate()
	add_child(fire)
	fire.scale=Vector2.ONE*0.42
	for i in 2:
		var wave=library.resource("effects/boss_wave/boss_wave.tscn").instantiate()
		add_child(wave)
		wave.scale=Vector2.ONE*0.45
		wave.face_right(i==1)
		waves.append(wave)
func _process(_delta:float) -> void:
	fire.visible=boss.mode==boss.Mode.WARN and boss.attack==boss.Attack.FIREBALL
	fire.position=boss.home-Vector2(0,100)
	if fire.visible: fire.sample("warning",1-boss.clock/0.95)
	for i in 2:
		waves[i].visible=boss.mode==boss.Mode.WARN and boss.attack==boss.Attack.HAMMER
		waves[i].position=boss.position+Vector2((-1 if i==0 else 1)*55,0)
		if waves[i].visible: waves[i].sample("warning",1-boss.clock/0.95)
