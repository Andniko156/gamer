extends Node2D

const Data = preload("res://scripts/catalog.gd")
const Run = preload("res://scripts/run_state.gd")
const HERO_ATLAS = preload("res://assets/heroes.png")
const ENEMY_ATLAS = preload("res://assets/enemies.png")
const ITEM_ATLAS = preload("res://assets/items.png")
const GOLD := Color("#ffc47c")
const TEAL := Color("#81dbc5")

@onready var hero_sprite: AnimatedSprite2D = $Hero
@onready var camera: Camera2D = $Hero/Camera2D
@onready var ui: CanvasLayer = $Interface

var run: FoundryRun
var overlay: PanelContainer
var hud: PanelContainer
var hud_title: Label
var hud_status: Label
var health: ProgressBar
var experience: ProgressBar
var selected := 0
var doctrine := 0
var stats := ConfigFile.new()
var touch_id := -1
var touch_anchor := Vector2.ZERO
var touch_current := Vector2.ZERO
var paused := false
var choosing_banish := false
var refresh := 0.0
var event_message := ""
var event_life := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stats.load("user://profile.cfg")
	_build_hud()
	_hangar()

func _build_hud() -> void:
	hud = PanelContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 10
	hud.offset_right = -10
	hud.offset_top = 12
	hud.add_theme_stylebox_override("panel", _panel(Color("#211b27"), Color("#805c48")))
	var row := HBoxContainer.new()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_title = _label("", 16, GOLD)
	hud_status = _label("", 12, TEAL)
	column.add_child(hud_title)
	health = _meter(Color("#ec806e"))
	experience = _meter(TEAL)
	column.add_child(health)
	column.add_child(experience)
	column.add_child(hud_status)
	row.add_child(column)
	var pause_button := _button("Ⅱ", _pause)
	pause_button.custom_minimum_size.x = 48
	row.add_child(pause_button)
	hud.add_child(row)
	ui.add_child(hud)
	hud.hide()

func _meter(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", _panel(Color("#3e2a3a"), Color("#3e2a3a"), 0))
	bar.add_theme_stylebox_override("fill", _panel(color, color, 0))
	return bar

func _physics_process(delta: float) -> void:
	if run == null or paused or not run.playing or run.picking:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction == Vector2.ZERO:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if touch_id != -1:
		direction = ((touch_current - touch_anchor) / 42.0).limit_length()
	run.step(delta, direction, get_viewport_rect().size)
	hero_sprite.position = run.position
	if direction.length_squared() > 0.004:
		if absf(direction.x) > 0.08:
			hero_sprite.flip_h = direction.x < 0.0
		hero_sprite.play("walk", lerpf(0.5, 1.25, direction.length()))
	else:
		hero_sprite.play("idle")
	if not run.message.is_empty():
		event_message = run.message
		event_life = 3.5
		run.message = ""
	event_life = maxf(0.0, event_life - delta)
	refresh -= delta
	if refresh <= 0.0:
		_update_hud()
		refresh = 0.10

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if run == null or not run.playing or run.picking:
		return
	if event.is_action_pressed("ui_cancel"):
		if paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			touch_anchor = event.position
			touch_current = event.position
		elif not event.pressed and touch_id == event.index:
			touch_id = -1
	elif event is InputEventScreenDrag and event.index == touch_id:
		touch_current = event.position

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud):
		_pause()

func _panel(fill: Color, edge: Color, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, margin)
	return style

func _label(value: String, size: int, color: Color = Color("#f4dfc7")) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 46
	button.add_theme_stylebox_override("normal", _panel(Color("#312531"), Color("#745447"), 6))
	button.add_theme_stylebox_override("hover", _panel(Color("#513747"), GOLD, 6))
	button.pressed.connect(action)
	return button

func _dismiss() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null

func _sheet(title: String) -> VBoxContainer:
	_dismiss()
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.custom_minimum_size.x = minf(370.0, get_viewport_rect().size.x - 24.0)
	overlay.add_theme_stylebox_override("panel", _panel(Color("#231d29"), GOLD, 15))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	contents.add_child(_label(title, 23, GOLD))
	overlay.add_child(contents)
	ui.add_child(overlay)
	return contents

func _hangar() -> void:
	run = null
	hud.hide()
	hero_sprite.hide()
	var panel := _sheet("ЛАТУННАЯ НОЧЬ")
	panel.add_child(_label("Литейная № 7 · вылазка на 10 минут", 15, TEAL))
	var crew := HBoxContainer.new()
	panel.add_child(crew)
	for index in Data.HERO_NAMES.size():
		var portrait := _button("", func() -> void: selected = index; _hangar())
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.icon = _region(HERO_ATLAS, Rect2(0, index * 28, 28, 28))
		portrait.expand_icon = true
		portrait.disabled = not _unlocked(index)
		portrait.tooltip_text = Data.HERO_NAMES[index]
		if index == selected:
			portrait.add_theme_stylebox_override("normal", _panel(Color("#503743"), GOLD, 6))
		crew.add_child(portrait)
	panel.add_child(_label(Data.HERO_NAMES[selected], 18))
	panel.add_child(_label("Оружие · " + Data.WEAPONS[selected], 14))
	var orders := OptionButton.new()
	orders.custom_minimum_size.y = 44
	orders.add_item("Полевой · +16 к дальности сбора опыта")
	orders.add_item("Штурмовой · +12% урона, +10% входящего")
	orders.add_item("Караульный · −14% входящего урона, −6% скорости")
	orders.select(doctrine)
	orders.item_selected.connect(func(index: int) -> void: doctrine = index)
	panel.add_child(orders)
	panel.add_child(_button("Начать вылазку", _start))
	var best: float = stats.get_value("progress", "time", 0.0)
	if best > 0.0:
		panel.add_child(_label("Рекорд · " + _format_time(best), 13, TEAL))
	panel.add_child(_label("WASD, стрелки или свайп по арене", 13))

func _unlocked(index: int) -> bool:
	match index:
		1: return float(stats.get_value("progress", "time", 0.0)) >= 45.0
		2: return int(stats.get_value("progress", "level", 0)) >= 5
		3: return int(stats.get_value("progress", "kills", 0)) >= 100
		4: return bool(stats.get_value("progress", "won", false))
	return true

func _start() -> void:
	_dismiss()
	run = Run.new()
	run.level_ready.connect(_level)
	run.ended.connect(_end)
	run.begin(selected, doctrine)
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", _region(HERO_ATLAS, Rect2(0, selected * 28, 28, 28)))
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 11.0)
	for frame in range(1, 5):
		frames.add_frame("walk", _region(HERO_ATLAS, Rect2(frame * 28, selected * 28, 28, 28)))
	hero_sprite.sprite_frames = frames
	hero_sprite.position = Vector2.ZERO
	hero_sprite.reset_physics_interpolation()
	camera.reset_smoothing()
	hero_sprite.scale = Vector2(2.0, 2.0)
	camera.position = Vector2.ZERO
	hero_sprite.show()
	hero_sprite.play("idle")
	hud.show()
	touch_id = -1
	paused = false
	event_life = 0.0
	choosing_banish = false
	_update_hud()

func _region(atlas: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	texture.filter_clip = true
	return texture

func _level() -> void:
	touch_id = -1
	hero_sprite.pause()
	var panel := _sheet("Исключить предмет" if choosing_banish else "Выберите усиление")
	for id in run.options:
		var rank := run.weapon[id] if id < 5 else (run.artifact[id - 5] if id < 11 else -1)
		var label := Run.item_name(id)
		if rank >= 0:
			label += " · %d/%d" % [rank + 1, 6 if id < 5 else 5]
		var choice := _button(label, func() -> void: _choose(id))
		choice.icon = _region(ITEM_ATLAS, Rect2((id if id < 11 else 12) * 18, 0, 18, 18))
		choice.disabled = choosing_banish and id >= 11
		panel.add_child(choice)
	var tools := HBoxContainer.new()
	var roll := _button("Сменить · %d" % run.rerolls, func() -> void: choosing_banish = false; run.reroll())
	roll.disabled = run.rerolls == 0
	roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var exclude := _button("Отмена" if choosing_banish else "Исключить · %d" % run.banishes, _toggle_banish)
	exclude.disabled = run.banishes == 0 or (run.options.size() == 1 and run.options[0] >= 11)
	exclude.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(roll)
	tools.add_child(exclude)
	panel.add_child(tools)

func _toggle_banish() -> void:
	choosing_banish = not choosing_banish
	_level()

func _choose(id: int) -> void:
	if choosing_banish:
		choosing_banish = false
		run.banish(id)
	else:
		run.choose(id)
		_dismiss()
	_update_hud()

func _pause() -> void:
	if run == null or not run.playing or run.picking or paused:
		return
	paused = true
	touch_id = -1
	hero_sprite.pause()
	var panel := _sheet("Пауза")
	panel.add_child(_button("Продолжить", _resume))
	panel.add_child(_button("Завершить вылазку", func() -> void: run.playing = false; _end(false)))

func _resume() -> void:
	paused = false
	_dismiss()

func _end(won: bool) -> void:
	hero_sprite.pause()
	_update_hud()
	stats.set_value("progress", "time", maxf(float(stats.get_value("progress", "time", 0.0)), run.time))
	stats.set_value("progress", "level", maxi(int(stats.get_value("progress", "level", 0)), run.level))
	stats.set_value("progress", "kills", int(stats.get_value("progress", "kills", 0)) + run.kills)
	stats.set_value("progress", "won", won or bool(stats.get_value("progress", "won", false)))
	stats.save("user://profile.cfg")
	var panel := _sheet("Литейная выстояла" if won else "Вылазка окончена")
	panel.add_child(_label("%s · уровень %d · врагов %d" % [_format_time(run.time), run.level, run.kills], 15, TEAL))
	panel.add_child(_button("Повторить", _start))
	panel.add_child(_button("В ангар", _hangar))

func _update_hud() -> void:
	hud_title.text = "%s  ·  %s" % [_format_time(run.time), Data.WAVE_NAMES[run.wave]]
	var status := "Ур. %d  ·  %d врагов  ·  %d/4 оружия  ·  %d/4 артефактов" % [run.level, run.kills, 5 - run.weapon.count(0), 6 - run.artifact.count(0)]
	if event_life > 0.0:
		status += "\n" + event_message
	if run.boss != null and not run.boss_defeated:
		status += "\nСмотритель · %d%%" % roundi(maxf(0.0, run.boss.hp / run.boss.max_hp) * 100)
	hud_status.text = status
	health.max_value = run.max_hp
	health.value = maxf(0.0, run.hp)
	experience.max_value = run.next_xp
	experience.value = run.xp

func _format_time(value: float) -> String:
	return "%02d:%02d" % [int(value / 60.0), int(value) % 60]

func _draw() -> void:
	if run == null:
		return
	var size := get_viewport_rect().size
	var center := camera.get_screen_center_position()
	var bounds := Rect2(center - size * 0.5 - Vector2(52, 52), size + Vector2(104, 104))
	draw_rect(bounds, Color("#211e29"))
	var first := (bounds.position / 48.0).floor()
	var last := (bounds.end / 48.0).ceil()
	for row in range(int(first.y), int(last.y)):
		for col in range(int(first.x), int(last.x)):
			var tile := Vector2(col * 48, row * 48)
			var choice := absi((col * 43 + row * 67) % 10)
			draw_rect(Rect2(tile + Vector2.ONE, Vector2(46, 46)), Color("#2d2933") if choice < 4 else Color("#26252e"))
			if choice == 7:
				draw_rect(Rect2(tile + Vector2(12,20), Vector2(24,8)), Color("#694b43"), false)
	var fraction := Engine.get_physics_interpolation_fraction() if not paused and run.playing and not run.picking else 1.0
	for item in run.loot:
		var at: Vector2 = item.position
		if not bounds.has_point(at):
			continue
		if item.kind == "xp":
			var color := Color("#f08c88") if item.xp >= 10 else (GOLD if item.xp >= 4 else TEAL)
			draw_rect(Rect2(at - Vector2(3,3), Vector2(6,6)), color)
		else:
			var item_index := 11 if item.kind == "chest" else 12
			if item.get("evolves", false):
				draw_circle(at, 16, Color("#81dbc538"))
			draw_texture_rect_region(ITEM_ATLAS, Rect2(at - Vector2(10,10), Vector2(20,20)), Rect2(item_index * 18,0,18,18))
	for unit in run.enemies:
		var at := unit.previous.lerp(unit.position, fraction)
		if not bounds.has_point(at):
			continue
		var side := 60.0 if unit.kind == 5 else (44.0 if unit.elite_time >= 0.0 else 35.0)
		if unit.elite_time >= 0.0:
			draw_arc(at, 15.0, 0.0, TAU, 20, GOLD, 1.5)
		draw_texture_rect_region(ENEMY_ATLAS, Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side), Rect2(unit.kind * 42,0,42,42))
		if unit.warning > 0.0:
			if unit.kind == 3:
				draw_line(at, at + unit.target * 115.0, Color("#ff8f7f88"), 10.0)
			else:
				var origin := unit.target if unit.kind == 4 else at
				var radius := 40.0 if unit.kind == 4 else (121.0 if unit.hp < unit.max_hp * 0.45 else 96.0)
				draw_arc(origin, radius, 0.0, TAU, 40, Color("#ff8f7f"), 2.0)
	for shot in run.shots:
		var at := shot.previous.lerp(shot.position, fraction)
		draw_line(at - shot.velocity.normalized() * 9.0, at, GOLD, 3.0)
	for point in run.disk_positions():
		draw_rect(Rect2(point - Vector2(5,5), Vector2(10,10)), Color("#a8e98b"))
	for effect in run.effects:
		_draw_effect(effect)
	if touch_id != -1:
		var origin: Vector2 = get_global_transform_with_canvas().affine_inverse() * touch_anchor
		var offset := (touch_current - touch_anchor).limit_length(39)
		draw_arc(origin, 39, 0.0, TAU, 28, Color("#ffc47c80"), 1.5)
		draw_circle(origin + offset, 12, Color("#ffc47c80"))

func _draw_effect(effect: Dictionary) -> void:
	var color: Color = effect.color
	color.a = clampf(effect.life / effect.duration, 0.16, 0.9)
	if effect.kind == "arc":
		draw_polyline(effect.points, color, 2.0)
		return
	var at: Vector2 = effect.position
	if effect.kind == "ring":
		draw_arc(at, effect.radius, effect.angle + 0.62, effect.angle + TAU - 0.62, 48, color, 2.0)
	elif effect.kind == "raid":
		for line in (2 if effect.cross else 1):
			var heading := Vector2.from_angle(effect.angle + line * PI / 2.0) * 235.0
			draw_line(at - heading, at + heading, Color(color, 0.12), 208.0)
			draw_line(at - heading, at + heading, color, 1.5)
	elif effect.kind == "cone":
		draw_arc(at, effect.radius, effect.angle - 0.82, effect.angle + 0.82, 20, color, 3.0)
	else:
		draw_arc(at, effect.radius * (1.0 - color.a * 0.35), 0.0, TAU, 32, color, 2.0)
