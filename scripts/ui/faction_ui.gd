extends RefCounted
const UI:=preload("res://scripts/core/ui_kit.gd")
const ROOT:="res://assets/faction_art/"

static func image_at(parent:Node,id:String,rect:Rect2) -> TextureRect:
	var image:=TextureRect.new()
	var folder:="ui/" if id in ["faction_hall","hero_human","hero_ogre"] else "decor/"
	image.texture=load(ROOT+folder+id+".png")
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	UI.place(image,parent,rect.position.x,rect.position.y,rect.size.x,rect.size.y)
	return image

static func decorate(parent:Node,page:String,hero:String) -> void:
	if page=="main":
		image_at(parent,"alliance_crest",Rect2(112,74,62,70))
		image_at(parent,"horde_crest",Rect2(786,74,62,70))
		image_at(parent,"alliance_standard",Rect2(32,315,156,320)).modulate=Color(0.85,0.87,0.95)
		image_at(parent,"horde_standard",Rect2(772,315,156,320)).modulate=Color(0.95,0.85,0.78)
	elif page!="heroes" and page!="occupied":
		var rect:=Rect2(10,80,30,35) if page=="play" else Rect2(837,61,34,39)
		image_at(parent,"horde_crest" if hero=="ogre" else "alliance_crest",rect)

static func heroes(host) -> void:
	var screen:Control=host.screen
	image_at(screen,"faction_hall",Rect2(0,0,960,540))
	var title:=UI.label(screen,"Выберите свою сторону",180,14,600,48,34)
	title.theme_type_variation="Heading"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sides:Array=[]
	var confirm:=Button.new()
	for i in 2:
		var id:="human" if i==0 else "ogre"
		var cx:=290+i*380
		var tone:=Color("#f2ce85") if i==0 else Color("#e7b179")
		var label:=UI.label(screen,"АЛЬЯНС — ЧЕЛОВЕК" if i==0 else "ОРДА — ОГР",cx-186,78,372,42,27,tone)
		label.theme_type_variation="Heading"
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var light:=ColorRect.new()
		light.color=Color(0.35,0.56,0.95,0.34) if i==0 else Color(0.95,0.29,0.12,0.34)
		var material:=ShaderMaterial.new()
		material.shader=preload("res://assets/faction_art/ui/selection_light.gdshader")
		light.material=material
		light.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UI.place(light,screen,cx-142,129,284,270)
		image_at(screen,"alliance_crest" if i==0 else "horde_crest",Rect2(cx-177 if i==0 else cx+125,151,52,62))
		var hero:=image_at(screen,"hero_"+id,Rect2(cx-130,134,260,246))
		hero.name="FullHero_"+id
		hero.flip_h=i==1
		var hit:=Button.new()
		hit.name="HeroHit_"+id
		hit.tooltip_text="Выбрать человека" if i==0 else "Выбрать огра"
		hit.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state in ["normal","hover","pressed","disabled","focus"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		UI.place(hit,screen,cx-142,130,284,312)
		var caption:=UI.label(screen,"Выбрать",cx-150,405,300,32,23,tone)
		caption.theme_type_variation="Heading"
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var side:={"id":id,"hit":hit,"hero":hero,"light":light,"caption":caption}
		sides.append(side)
		var refresh:=func(): refresh_side(side,host.selected)
		hit.mouse_entered.connect(refresh)
		hit.mouse_exited.connect(refresh)
		hit.focus_entered.connect(refresh)
		hit.focus_exited.connect(refresh)
		hit.pressed.connect(func():
			host.selected=id
			SFX.play("ui_click",hit)
			confirm.disabled=false
			for item in sides: refresh_side(item,host.selected))
		refresh_side(side,host.selected)
	confirm.text="Подтвердить выбор"
	confirm.name="ConfirmHero"
	confirm.theme_type_variation="PrimaryButton"
	confirm.disabled=host.selected.is_empty()
	UI.place(confirm,screen,280,472,400,48)
	confirm.pressed.connect(func(): SFX.play("ui_click",confirm); host.pages.start_campaign())
	UI.button(screen,"Назад",host.show_page.bind("main"),50,472,180)

static func refresh_side(side:Dictionary,selected:String) -> void:
	var active:bool=selected==side.id
	var hover:bool=side.hit.is_hovered() or side.hit.has_focus()
	side.light.visible=active or hover
	side.hero.modulate=Color(1.08,1.05,1.0) if hover else (Color.WHITE if active else Color(0.91,0.91,0.95))
	side.caption.text="Выбрано" if active else "Выбрать"
