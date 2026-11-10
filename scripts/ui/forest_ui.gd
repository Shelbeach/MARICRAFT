extends RefCounted
## Shared P05 UI for both chapters. Historical filename retained for existing callers.
const ROOT:="res://assets/ui_art/"
static var registry:Dictionary={}
static var ready:=false
static var textures:Dictionary={}

static func initialize() -> void:
	if ready: return
	ready=true
	registry=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"registry.json"))
	for name in ["Alegreya-ExtraBold.ttf","AlegreyaSans-Bold.ttf","AlegreyaSans-Medium.ttf"]:
		var font:FontFile=load(ROOT+"fonts/"+name)
		font.allow_system_fallback=false

static func theme() -> Theme:
	initialize()
	return load("res://assets/faction_art/maricraft_p06.theme.tres")

static func texture(id:String) -> Texture2D:
	initialize()
	if not textures.has(id): textures[id]=load(ROOT+str(registry[id].file).trim_prefix("runtime/"))
	return textures[id]

static func icon(parent:Node,id:String,at:Vector2,size:=Vector2.ZERO) -> TextureRect:
	initialize()
	if size==Vector2.ZERO: size=Vector2(registry[id].recommended_display[0],registry[id].recommended_display[1])
	var node:=TextureRect.new()
	node.texture=texture(id)
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position=at
	node.size=size
	return node

static func panel(parent:Node,rect:Rect2) -> Panel:
	var node:=Panel.new()
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position=rect.position
	node.size=rect.size
	return node

static func frame(parent:Node,id:String,rect:Rect2,margin:=9) -> NinePatchRect:
	var node:=NinePatchRect.new()
	node.texture=texture(id)
	node.patch_margin_left=margin
	node.patch_margin_right=margin
	node.patch_margin_top=margin
	node.patch_margin_bottom=margin
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position=rect.position
	node.size=rect.size
	return node

static func background(parent:Node) -> void:
	icon(parent,"menu_far",Vector2.ZERO)
	icon(parent,"menu_edge",Vector2.ZERO)
