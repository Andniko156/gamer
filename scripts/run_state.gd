class_name FoundryRun
extends RefCounted

signal level_ready
signal ended(won: bool)

const Data = preload("res://scripts/catalog.gd")
const ENEMY_HP := [22.0,34.0,102.0,73.0,78.0,3200.0]
const ENEMY_SPEED := [44.0,66.0,38.0,48.0,44.0,57.0]
const ENEMY_RADIUS := [8.0,9.0,15.0,12.0,12.0,25.0]
const ENEMY_DAMAGE := [9.0,13.0,20.0,18.0,14.0,34.0]
const ENEMY_XP := [1,2,4,3,3,20]

class Unit:
	var position: Vector2
	var previous: Vector2
	var hp: float
	var max_hp: float
	var kind: int
	var elite_time: float
	var warning := 0.0
	var interval := 3.0
	var charge := 0.0
	var target := Vector2.ZERO
	var sweep := Vector2.ZERO
	var sweep_time := 0.0

class Shot:
	var position: Vector2
	var previous: Vector2
	var velocity: Vector2
	var hits: Array[Unit] = []
	var life := 0.76
	var damage: float
	var pierce: int

var rng := RandomNumberGenerator.new()
var hero := 0
var position := Vector2.ZERO
var heading := Vector2.RIGHT
var hp := 100.0
var max_hp := 100.0
var time := 0.0
var kills := 0
var xp := 0
var level := 1
var next_xp := 16
var weapon := PackedInt32Array()
var artifact := PackedInt32Array()
var evolved := PackedByteArray()
var cooldown := PackedFloat32Array()
var options: Array[int] = []
var enemies: Array[Unit] = []
var shots: Array[Shot] = []
var loot: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var boss: Unit
var boss_defeated := false
var playing := false
var picking := false
var message := ""
var rerolls := 2
var banishes := 1
var banned: Array[int] = []
var wave: int:
	get: return mini(9, int(time / 60.0))
var _next_spawn := 0.0
var _elite := 0
var _event := 0
var _formation_origin := Vector2.ZERO
var _formation_angle := 0.0
var _formation_release := -1.0
var _invulnerability := 0.0
var doctrine := 0

func begin(hero_index: int, doctrine_index: int = 0) -> void:
	doctrine = doctrine_index
	hero = hero_index
	max_hp = Data.HERO_HEALTH[hero]
	hp = max_hp
	weapon.resize(5)
	artifact.resize(6)
	evolved.resize(5)
	cooldown.resize(5)
	weapon[hero] = 1
	rng.randomize()
	playing = true
	for i in 10:
		_spawn(0, 110.0 + i % 4 * 24.0, float(i) * TAU / 11.0)

func step(delta: float, movement: Vector2, viewport: Vector2) -> void:
	if not playing or picking:
		return
	time = minf(time + delta, Data.RUN_SECONDS)
	if movement.length_squared() > 0.002:
		heading = movement.normalized()
	position += movement.limit_length() * Data.HERO_SPEED[hero] * (0.94 if doctrine == 2 else 1.0) * (1.0 + artifact[4] * 0.06) * delta
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_spawn_waves(viewport)
	_attack(delta)
	_move_shots(delta)
	for enemy in enemies:
		if enemy.hp > 0.0:
			_move_enemy(enemy, delta)
	_separate_enemies(delta)
	enemies = enemies.filter(func(unit: Unit) -> bool:
		return unit.hp > 0.0 and (unit == boss or unit.elite_time >= 0.0 or unit.position.distance_squared_to(position) < 1200.0 ** 2))
	_collect()
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0.0)
	if hp <= 0.0 or time >= Data.RUN_SECONDS:
		playing = false
		ended.emit(hp > 0.0 and boss_defeated)
	elif xp >= next_xp:
		xp -= next_xp
		level += 1
		next_xp = Data.xp_target(level)
		picking = true
		_deal()

func _spawn(kind: int, distance: float, angle: float, elite_time: float = -1.0) -> Unit:
	var unit := Unit.new()
	unit.kind = kind
	unit.elite_time = elite_time
	unit.position = position + Vector2.from_angle(angle) * distance
	unit.previous = unit.position
	var scale := 1.0 if kind == 5 else 1.0 + time / 770.0
	unit.hp = ENEMY_HP[kind] * scale * (2.5 if elite_time >= 0.0 else 1.0)
	unit.max_hp = unit.hp
	unit.interval = 4.0 if kind == 5 else rng.randf_range(1.6, 3.7)
	enemies.append(unit)
	return unit

func _spawn_waves(viewport: Vector2) -> void:
	if time >= Data.BOSS_TIME and boss == null:
		boss = _spawn(5, 180.0, rng.randf_range(0.0, TAU))
		message = "Смотритель на арене"
	if _elite < Data.ELITE_TIMES.size() and time >= Data.ELITE_TIMES[_elite]:
		_spawn(Data.ELITE_KINDS[_elite], 215.0, rng.randf_range(0.0, TAU), Data.ELITE_TIMES[_elite])
		_elite += 1
		message = "Элита несёт шкатулку"
	_formations()
	if time < _next_spawn:
		return
	var breather := fposmod(time, 60.0) >= 49.0 and fposmod(time, 60.0) < 56.0
	_next_spawn = time + Data.WAVE_INTERVALS[wave] * (1.35 if breather else 1.0)
	var limit := mini((Data.WAVE_COUNTS[wave] + 1) / 2 if breather else Data.WAVE_COUNTS[wave], 46 + wave * 8 - enemies.size())
	var roster: Array = Data.WAVE_ROSTERS[wave]
	var angle := rng.randf_range(0.0, TAU)
	var rams := 0
	var mortars := 0
	for unit in enemies:
		rams += int(unit.kind == 3)
		mortars += int(unit.kind == 4)
	for i in range(limit):
		var kind: int = roster[rng.randi_range(0, roster.size() - 1)]
		if time < 24.0 or (kind == 3 and rams >= 7) or (kind == 4 and mortars >= 3):
			kind = 0
		rams += int(kind == 3)
		mortars += int(kind == 4)
		var direction := angle + i * 0.26 + (PI if i % 2 and wave >= 5 else 0.0)
		var axis := Vector2.from_angle(direction).abs()
		var distance := minf(viewport.x * 0.5 / maxf(axis.x, 0.001), viewport.y * 0.5 / maxf(axis.y, 0.001))
		_spawn(kind, minf(distance, 350.0) + 24.0, direction)

func _formations() -> void:
	if _event >= Data.EVENT_TIMES.size():
		return
	if _formation_release < 0.0 and time >= Data.EVENT_TIMES[_event]:
		_formation_origin = position
		_formation_angle = rng.randf_range(0.0, TAU)
		_formation_release = time + 2.0
		message = Data.EVENT_NAMES[_event]
		effects.append({"kind": "ring" if _event % 2 else "raid", "position": position, "radius": 205.0, "angle": _formation_angle, "cross": _event == 2, "life": 2.0, "duration": 2.0, "color": Color("#ffc583")})
	if _formation_release < 0.0 or time < _formation_release:
		return
	if _event % 2:
		for i in range(2, 14):
			var direction := Vector2.from_angle(_formation_angle + i * TAU / 15.0)
			var unit := _spawn(2 if _event == 3 and i % 3 == 0 else 0, 0.0, 0.0)
			unit.position = _formation_origin + direction * 205.0
			unit.previous = unit.position
	else:
		for line in (2 if _event == 2 else 1):
			var direction := Vector2.from_angle(_formation_angle + line * PI / 2.0)
			for i in range(-4,5):
				var unit := _spawn(1, 0.0, 0.0)
				unit.position = _formation_origin + direction * 235.0 + direction.orthogonal() * i * 26.0
				unit.previous = unit.position
				unit.sweep = -direction
				unit.sweep_time = 3.8
	_event += 1
	_formation_release = -1.0

func _move_enemy(unit: Unit, delta: float) -> void:
	unit.previous = unit.position
	var offset := position - unit.position
	var distance := offset.length()
	var velocity := offset.normalized()
	var enraged := unit.kind == 5 and unit.hp < unit.max_hp * 0.45
	if unit.sweep_time > 0.0:
		unit.position += unit.sweep * delta * 118.0
		unit.sweep_time -= delta
	elif unit.charge > 0.0:
		unit.position += unit.target * delta * 220.0
		unit.charge -= delta
	elif unit.warning <= 0.0 and distance > (155.0 if unit.kind == 4 else ENEMY_RADIUS[unit.kind] + 4.0):
		unit.position += velocity * ENEMY_SPEED[unit.kind] * delta * (1.24 if enraged else 1.0)
	if unit.position.distance_squared_to(position) < (ENEMY_RADIUS[unit.kind] + 8.0) ** 2:
		_hurt(ENEMY_DAMAGE[unit.kind])
	if unit.kind < 3:
		return
	if unit.warning > 0.0:
		unit.warning -= delta
		if unit.warning <= 0.0:
			if unit.kind == 3:
				unit.charge = 0.52
			else:
				var origin := unit.target if unit.kind == 4 else unit.position
				var radius := 40.0 if unit.kind == 4 else (121.0 if enraged else 96.0)
				if origin.distance_squared_to(position) < radius * radius:
					_hurt(19.0 if unit.kind == 4 else 36.0)
				_effect(origin, radius, Color("#ff8374"))
	else:
		unit.interval -= delta
		if unit.interval <= 0.0 and distance < (130.0 if unit.kind == 3 else 250.0):
			unit.warning = 0.76 if unit.kind == 3 else 1.30
			unit.interval = 4.7 if unit.kind != 5 else 3.8
			unit.target = velocity if unit.kind == 3 else position

func _separate_enemies(delta: float) -> void:
	var grid: Dictionary[Vector2i, Array] = {}
	for unit in enemies:
		if unit.hp <= 0.0:
			continue
		var cell := Vector2i((unit.position / 48.0).floor())
		for y in range(-1, 2):
			for x in range(-1, 2):
				for other: Unit in grid.get(cell + Vector2i(x, y), []):
					var shift := unit.position - other.position
					var separation := shift.length()
					var overlap: float = (ENEMY_RADIUS[unit.kind] + ENEMY_RADIUS[other.kind]) * 0.80 - separation
					if overlap <= 0.0:
						continue
					var normal := shift / separation if separation > 0.001 else Vector2.RIGHT
					var correction := normal * minf(delta * 32.0, overlap * 0.36)
					if unit.kind != 5:
						unit.position += correction
					if other.kind != 5:
						other.position -= correction
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(unit)

func _hurt(damage: float) -> void:
	if _invulnerability > 0.0:
		return
	_invulnerability = 0.65
	hp -= damage * (0.86 if doctrine == 2 else (1.10 if doctrine == 1 else 1.0)) * (0.76 if hero == 3 else 1.0) * (1.0 - artifact[3] * 0.07)

func _damage(unit: Unit, amount: float) -> void:
	if unit.hp <= 0.0:
		return
	unit.hp -= amount * (1.12 if doctrine == 1 else 1.0) * (1.18 if hero == 1 else 1.0) * (1.0 + artifact[0] * 0.08)
	if unit.hp > 0.0:
		return
	kills += 1
	boss_defeated = boss_defeated or unit == boss
	var orb := {"position": unit.position, "xp": ENEMY_XP[unit.kind], "kind": "xp"}
	var merge_target: Dictionary = {}
	if loot.size() >= 240:
		for item in loot:
			if item.kind == "xp" and (merge_target.is_empty() or item.xp > merge_target.xp):
				merge_target = item
	if merge_target.is_empty():
		loot.append(orb)
	else:
		merge_target.xp += orb.xp
	if unit.elite_time >= 0.0:
		loot.append({"position": unit.position, "kind": "chest", "evolves": unit.elite_time >= 195.0})
	if kills % 31 == 0 and hp < max_hp:
		loot.append({"position": unit.position + Vector2(14.0, 0.0), "kind": "heal"})

func _closest(origin: Vector2, distance: float, ignore: Array[Unit]) -> Unit:
	var target: Unit
	var best := distance * distance
	for unit in enemies:
		var squared := origin.distance_squared_to(unit.position)
		if unit.hp > 0.0 and squared < best and unit not in ignore:
			best = squared
			target = unit
	return target

func _attack(delta: float) -> void:
	var area := (1.22 if hero == 2 else 1.0) * (1.0 + artifact[2] * 0.07)
	for kind in weapon.size():
		var rank := weapon[kind]
		if rank == 0:
			continue
		cooldown[kind] -= delta
		if cooldown[kind] > 0.0:
			continue
		var advanced := evolved[kind] > 0
		var target := _closest(position, 340.0 if kind == 0 else 240.0 * area, [])
		if target == null:
			continue
		var angle := position.angle_to_point(target.position)
		var recharge := 0.74
		match kind:
			0:
				var count := 5 if advanced else 1 + int(rank >= 2) + int(rank >= 4)
				for index in count:
					var shot := Shot.new()
					shot.position = position
					shot.previous = position
					shot.velocity = Vector2.from_angle(angle + (index - (count - 1) * 0.5) * 0.12) * 445.0
					shot.damage = 54.0 if advanced else 21.0 + rank * 4.0
					shot.pierce = 3 if advanced else (2 if rank >= 5 else 1)
					shots.append(shot)
				recharge = 0.48 if advanced else 0.74 - rank * 0.014
			1:
				var hit: Array[Unit] = []
				var points := PackedVector2Array([position])
				for index in (7 if advanced else 2 + rank / 2):
					if target == null:
						break
					hit.append(target)
					points.append(target.position)
					_damage(target, 64.0 if advanced else 20.0 + rank * 4.0)
					target = _closest(target.position, 108.0 * area, hit)
				effects.append({"kind": "arc", "points": points, "life": 0.19, "duration": 0.19, "color": Data.COLORS[kind]})
				recharge = 0.73 if advanced else 1.12 - rank * 0.028
			2, 3:
				var radius := (175.0 if advanced else 81.0 + rank * 9.0) * area
				if kind == 2 and absf(wrapf(heading.angle() - angle, -PI, PI)) < 0.83:
					angle = heading.angle()
				if position.distance_to(target.position) > radius:
					continue
				for unit in enemies:
					var range_to := position.distance_to(unit.position)
					if range_to > radius:
						continue
					if kind == 2 and absf(wrapf(position.angle_to_point(unit.position) - angle, -PI, PI)) > (1.35 if advanced else 0.82):
						continue
					_damage(unit, (70.0 if kind == 2 else 106.0) if advanced else 23.0 + rank * 6.0)
					if kind == 3 and rank >= 4 and unit.kind != 5 and unit.elite_time < 0.0:
						unit.position += position.direction_to(unit.position) * (33.0 if advanced else 12.0)
				_effect(position, radius, Data.COLORS[kind], "cone" if kind == 2 else "pulse", angle)
				recharge = 0.64 if advanced else 1.06 - rank * 0.026
			4:
				for point in disk_positions():
					for unit in enemies:
						if point.distance_squared_to(unit.position) < (ENEMY_RADIUS[unit.kind] + (22.0 if advanced else 16.0) * area) ** 2:
							_damage(unit, 49.0 if advanced else 20.0 + rank * 4.0)
				recharge = 0.22 if advanced else 0.32
		cooldown[kind] = recharge * (1.0 - artifact[1] * 0.06)

func disk_positions() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if weapon[4] > 0:
		var count := 3 if evolved[4] else (2 if weapon[4] >= 3 else 1)
		for i in count:
			points.append(position + Vector2.from_angle(time * 5.0 + i * TAU / count) * (39.0 if evolved[4] else 32.0))
	return points

func _move_shots(delta: float) -> void:
	for shot in shots:
		shot.previous = shot.position
		shot.position += shot.velocity * delta
		shot.life -= delta
		var segment := shot.position - shot.previous
		var occupied := segment.length_squared()
		for unit in enemies:
			if shot.pierce <= 0:
				break
			if unit.hp <= 0.0 or unit in shot.hits:
				continue
			var fraction := clampf((unit.position - shot.previous).dot(segment) / maxf(occupied, 0.001), 0.0, 1.0)
			if unit.position.distance_squared_to(shot.previous + segment * fraction) < (ENEMY_RADIUS[unit.kind] + 3.0) ** 2:
				shot.hits.append(unit)
				shot.pierce -= 1
				_damage(unit, shot.damage)
	shots = shots.filter(func(shot: Shot) -> bool: return shot.life > 0.0 and shot.pierce > 0)

func _effect(origin: Vector2, radius: float, color: Color, kind: String = "pulse", angle: float = 0.0) -> void:
	effects.append({"kind": kind, "position": origin, "radius": radius, "color": color, "life": 0.4, "duration": 0.4, "angle": angle})

func _collect() -> void:
	for i in range(loot.size() - 1, -1, -1):
		var item := loot[i]
		var location: Vector2 = item.position
		var distance := location.distance_to(position)
		if distance < (23.0 if item.kind == "chest" else 13.0):
			if item.kind == "xp":
				xp += item.xp
			elif item.kind == "heal":
				hp = minf(max_hp, hp + max_hp * 0.24)
			else:
				_open_chest(item.evolves)
			loot.remove_at(i)
		elif item.kind == "xp" and distance < 45.0 + (16.0 if doctrine == 0 else 0.0) + artifact[5] * 16.0 + (18.0 if hero == 0 else 0.0):
			item.position = location.move_toward(position, 5.0)

func _eligible() -> Array[int]:
	var result: Array[int] = []
	for i in weapon.size():
		if i not in banned and weapon[i] < 6 and (weapon[i] > 0 or 5 - weapon.count(0) < Data.WEAPON_SLOTS):
			result.append(i)
	for i in artifact.size():
		if i + 5 not in banned and artifact[i] < 5 and (artifact[i] > 0 or 6 - artifact.count(0) < Data.ARTIFACT_SLOTS):
			result.append(i + 5)
	return result

func _deal(previous: Array[int] = []) -> void:
	var pool := _eligible()
	pool.shuffle()
	options = []
	if previous.is_empty():
		for key in [hero, hero + 5]:
			if key in pool:
				options.append(key)
				pool.erase(key)
	else:
		for key in previous:
			if key in pool:
				pool.erase(key)
				pool.append(key)
	while options.size() < 3 and not pool.is_empty():
		options.append(pool.pop_front())
	if options.is_empty() or hp < max_hp * 0.43:
		if options.size() == 3:
			options.pop_back()
		options.append(11)
	level_ready.emit()

func reroll() -> void:
	if picking and rerolls > 0:
		rerolls -= 1
		_deal(options)

func banish(id: int) -> void:
	if picking and banishes > 0 and id in options and id < 11:
		banishes -= 1
		banned.append(id)
		_deal()

func choose(id: int) -> void:
	if not picking or id not in options:
		return
	_upgrade(id)
	options.clear()
	picking = false

func _upgrade(id: int) -> void:
	if id < 5:
		weapon[id] += 1
	elif id < 11:
		artifact[id - 5] += 1
	else:
		hp = minf(max_hp, hp + max_hp * 0.30)

func _open_chest(can_evolve: bool) -> void:
	for i in weapon.size():
		if can_evolve and weapon[i] == 6 and artifact[i] >= 3 and not evolved[i]:
			evolved[i] = 1
			message = Data.EVOLUTIONS[i]
			return
	var pool := _eligible().filter(func(id: int) -> bool: return (weapon[id] if id < 5 else artifact[id - 5]) > 0)
	var id: int = 11 if pool.is_empty() or hp < max_hp * 0.45 else pool[rng.randi_range(0, pool.size() - 1)]
	_upgrade(id)
	message = "Шкатулка · " + item_name(id)

static func item_name(id: int) -> String:
	if id < 5:
		return Data.WEAPONS[id]
	if id < 11:
		return Data.ARTIFACTS[id - 5]
	return "Ремкомплект"
