extends RefCounted
const ForestUI:=preload("res://scripts/ui/forest_ui.gd")
const UI:=preload("res://scripts/core/ui_kit.gd")
const FactionUI:=preload("res://scripts/ui/faction_ui.gd")
var host
var screen:Control
var volumes:={}
var mutes:={}

func text(s:String,x:int,y:int,w:int,h:=32,sz:=22,col:=UI.PAPER) -> Label:
	return UI.label(screen,s,x,y,w,h,sz,col)

func button(s:String,cb:Callable,x:int,y:int,w:=236,primary:=false) -> Button:
	return UI.button(screen,s,cb,x,y,w,48,primary)

func go(page:String) -> Callable: return host.show_page.bind(page)

func wrapped(message:String,y:int,h:int) -> Label:
	var node:=Label.new()
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# Give wrapping a width before text/theme notification computes its minimum height.
	# Otherwise the initial zero-width layout can leave a 2500px-tall centred label.
	node.size=Vector2(784,h)
	node.text=message
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	UI.place(node,screen,88,y,784,h)
	return node

func heading(kicker:String,title:String) -> void:
	text(kicker,88,65,784,24,18,UI.MINT)
	var label:=Label.new()
	label.theme_type_variation="Heading"
	label.text=title
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	UI.place(label,screen,88,94,784,62)

func draw(page:String,message:String) -> void:
	screen=host.screen
	if page in ["map","victory"]:
		if page=="map": map_page()
		else: victory()
		return
	if page=="heroes":
		heroes()
		return
	ForestUI.background(screen)
	if page!="main": ForestUI.panel(screen,Rect2(58,44,844,452))
	match page:
		"main": main()
		"heroes": heroes()
		"map": map_page()
		"settings": settings_page()
		"result": result()
		"victory": victory()
		"offer": offer()
		"defeat": defeat()
		"occupied":
			heading("ПРОФИЛЬ ЗАНЯТ","Игра открыта в другой вкладке")
			wrapped("Закройте предыдущую вкладку и обновите эту страницу.",213,70)
		"pause":
			heading("УРОВЕНЬ "+Campaign.p.level,"Пауза")
			button("Продолжить",go("play"),320,187,320,true)
			button("Начать уровень заново",host.ask.bind("Вернуться к старту? Потраченные сердца и полученные награды сохранятся.",host.start_level),320,249,320)
			button("Настройки",host.options,320,311,320)
			button("В главное меню",host.ask.bind("Выйти? При продолжении вы начнёте со старта с текущим кошельком и сердцами.",host.main_menu),320,373,320)
		"confirm":
			heading("ПОДТВЕРЖДЕНИЕ","Подтвердите действие")
			wrapped(message,190,118)
			button("Да, продолжить",host.pending,88,365,280,true)
			button("Нет, вернуться",go(host.cancel_page),390,365,280)
		"future":
			heading("УРОВЕНЬ НЕДОСТУПЕН","Не удалось открыть уровень")
			wrapped("Сердца, монеты и результаты сохранены. Вернитесь в меню и продолжите игру.",206,90)
			button("В главное меню",host.main_menu,88,380,280,true)
	FactionUI.decorate(screen,page,Campaign.p.get("hero","human"))

func main() -> void:
	var title:=Label.new()
	title.text="MARICRAFT"
	title.theme_type_variation="Title"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	UI.place(title,screen,100,89,760,100)
	button("Новая игра",request_new,320,252,320,true)
	var resume:=button("Продолжить",resume_game,320,316,320)
	resume.disabled=Campaign.p.is_empty() or (Campaign.p.status=="defeat" and not Campaign.p.get("completed",false))
	var levels:=button("Выбор уровней",choose_levels,320,380,320)
	levels.name="LevelSelect"
	levels.disabled=not Campaign.p.get("completed",false)
	levels.tooltip_text="Откроется после прохождения кампании" if levels.disabled else "Переиграть любой из девяти уровней"
	button("Настройки",host.options,320,444,320)

func choose_levels() -> void:
	# Enforce the same gate even if a stale UI callback is invoked directly.
	if not Campaign.p.get("completed",false): return
	host.map_selected=Campaign.p.get("last_level",Campaign.p.level)
	host.next_map()

func heroes() -> void:
	FactionUI.heroes(host)

func map_page() -> void:
	var free:bool=Campaign.p.get("completed",false)
	if host.map_selected.is_empty() or not free: host.map_selected=Campaign.p.level
	var map=preload("res://assets/molten_art/ui/world_map.tscn").instantiate()
	map.name="WorldMap"
	screen.add_child(map)
	var data:Array=[]
	for id in Campaign.ROUTE:
		var state_name:String="completed" if Campaign.p.results.has(id) else "locked"
		if free: state_name="completed" if Campaign.p.records.has(id) else "available"
		elif id==Campaign.p.level: state_name="current"
		data.append({"id":id,"state":state_name,"stars":Campaign.p.records.get(id,{}).get("stars",0)})
	map.set_progress(data,host.map_selected,free)
	map.level_selected.connect(func(id): host.map_selected=id)
	map.start_requested.connect(func(id):
		host.map_selected=id
		if free: launch_selected()
		elif id==Campaign.p.level: host.start_level())
	map.start_button.text="Играть" if free else "Продолжить"
	var back:=button("Меню",host.main_menu,786,10,142)
	back.name="MapMenu"

func select_map(id:String) -> void:
	host.map_selected=id
	host.show_page("map")

func launch_selected() -> void:
	if Campaign.start_replay(host.map_selected): host.start_level()

func victory() -> void:
	var view=preload("res://assets/molten_art/ui/finale.tscn").instantiate()
	view.name="CampaignFinale"
	screen.add_child(view)
	var stars:=0
	for record in Campaign.p.records.values(): stars+=int(record.stars)
	view.present("victory",{"stars":"%d / 27"%stars,"coins":Campaign.p.wallet,"time":UI.clock(Campaign.p.seconds),"score":Campaign.p.score,"record":Campaign.total_record()})
	view.map_requested.connect(host.next_map)
	view.replay_requested.connect(func():
		host.map_selected="3-3"
		launch_selected())

func settings_page() -> void:
	heading("ПАРАМЕТРЫ","Настройки")
	for i in 2:
		var bus:String=["Музыка","Эффекты"][i]
		var y:=196+i*72
		volumes[bus]=Campaign.volume(bus)
		mutes[bus]=Campaign.muted(bus)
		text(bus,88,y,130,36)
		var slider:=HSlider.new()
		slider.max_value=100
		slider.step=10
		slider.value=volumes[bus]
		UI.place(slider,screen,225,y+5,330,28)
		var value:=UI.counter(screen,str(volumes[bus])+"%",576,y,72,36)
		slider.value_changed.connect(func(v): volumes[bus]=int(v); value.text=str(int(v))+"%")
		var mute:=CheckButton.new()
		mute.text="Без звука"
		mute.button_pressed=mutes[bus]
		UI.place(mute,screen,674,y-6,198,48)
		mute.toggled.connect(func(on): mutes[bus]=on)
		mute.toggled.connect(func(_on): SFX.play("ui_click",mute))
	for item in [["A / D","Движение",88,94],["Пробел","Прыжок",305,96],["E","Магия",539,48],["Esc","Пауза",714,56]]:
		ForestUI.frame(screen,"keycap",Rect2(item[2],343,item[3],36),8)
		var key:=text(item[0],item[2],343,item[3],36,20)
		key.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		text(item[1],item[2]+item[3]+8,345,116,32,18,UI.MUTED)
	button("Применить",save_settings,88,414,260,true)
	button("Назад",go(host.back_page),370,414,180)

func offer() -> void:
	heading("ПОСЛЕДНЕЕ СЕРДЦЕ","Продолжить путь?")
	ForestUI.icon(screen,"hud_coin",Vector2(88,200))
	UI.counter(screen,"Кошелёк    %d монет" % Campaign.p.wallet,128,194,720,40)
	text("Одно сердце вернёт героя к безопасной точке.",88,252,784,40)
	var buy:=button("Купить 1 сердце — %d монет" % Campaign.price(),host.purchase,88,329,420,true)
	buy.disabled=Campaign.p.wallet<Campaign.price()
	var message:String="Завершить эту попытку? Банк монет и рекорды сохранятся. Затем можно выбрать любой уровень на карте." if Campaign.p.completed else "Завершить кампанию? Вы увидите статистику. Следующая попытка начнётся с "+Campaign.store.first_level+"."
	button("Завершить попытку",host.ask.bind(message,host.end_attempt),530,329,342)
	if buy.disabled: text("Для покупки не хватает %d монет." % (Campaign.price()-Campaign.p.wallet),88,406,784,36,20,UI.MUTED)

func result() -> void:
	var r:Dictionary=Campaign.p.last_result
	heading("ИТОГИ   /   "+Campaign.last_level(),Campaign.NAMES[Campaign.last_level()]+" · пройдено")
	UI.symbols(screen,"stars",r.stars,88,182,44)
	UI.counter(screen,"%d очк.  ·  %d / 3 звёзд" % [r.score,r.stars],276,184,596,40)
	UI.counter(screen,"Монеты   %d / %d       Очки   %d       Враги   %d" % [r.coins,r.total,r.score,r.enemies],88,252,784,34)
	UI.counter(screen,"Потеряно сердец   %d       Время   %s" % [r.lost,UI.clock(r.seconds)],88,295,784,34)
	text("1. Финиш    2. От %d монет (80%%)    3. Вдобавок сохранить все сердца" % ceili(r.total*0.8),88,350,784,42,18,UI.MUTED)
	button("Карта уровней" if Campaign.p.completed else "Следующий уровень",host.next_map,88,414,290,true)
	button("В главное меню",leave_result,400,414,270)

func defeat() -> void:
	var p:=Campaign.p
	heading("КОНЕЦ ПОПЫТКИ" if p.completed else "КОНЕЦ ЭКСПЕДИЦИИ","Попытка завершена" if p.completed else "Кампания завершена")
	text("Достигнут уровень   "+p.level,88,183,784,40,28,UI.GOLD)
	UI.counter(screen,"Заработано   %d       Потрачено   %d       В кошельке   %d" % [p.earned,p.spent,p.wallet],88,245,784,34)
	UI.counter(screen,"Куплено сердец   %d       Очки   %d       Враги   %d" % [p.purchases,p.score,p.enemies],88,290,784,34)
	UI.counter(screen,"Время кампании   "+UI.clock(p.seconds),88,335,784,34)
	button("Карта уровней" if p.completed else "Начать заново",go("map") if p.completed else request_new,88,414,280,true)
	button("В главное меню",host.main_menu,390,414,270)

func request_new() -> void:
	host.selected = ""
	if not Campaign.p.is_empty() or not Campaign.store.notice.is_empty():
		host.ask("Начать новую кампанию? После выбора героя прежний прогресс будет заменён.",go("heroes"))
	else:
		host.show_page("heroes")


func resume_game() -> void:
	if Campaign.p.get("completed",false) and Campaign.p.status in ["map","defeat"]:
		host.show_page("map")
		return
	match Campaign.p.status:
		"result","offer","defeat","victory": host.show_page(Campaign.p.status)
		_: host.start_level()


func select_hero(id: String) -> void:
	host.selected = id
	host.show_page("heroes")


func start_campaign() -> void:
	Campaign.new_game(host.selected)
	host.show_page("map")


func save_settings() -> void:
	Campaign.store_options(volumes,mutes)
	host.show_page(host.back_page)


func leave_result() -> void:
	Campaign.leave_result()
	host.main_menu()

