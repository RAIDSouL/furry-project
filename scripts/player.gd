extends CharacterBody3D

## Player controller implementing PLAYER_SYSTEM.md (adapted to Godot).
## State machine: Idle / Move / Jump / Dodge, fed by a single-slot input buffer.
## Controls: WASD move (camera-relative), Ctrl = sprint toggle (free),
## Shift = dodge (i-frames, costs stamina, chains), Space = jump (coyote + variable
## height), Mouse = look, Esc = free cursor.

enum State { IDLE, MOVE, JUMP, DODGE, ATTACK }
enum CamMode { TPS, ISO }   # third-person  |  isometric click-to-move (Lost Ark style)

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.5
@export var accel_time: float = 0.1       # SmoothDamp-like smoothing time (start)
@export var stop_time: float = 0.05       # faster smoothing when stopping (crisp stop)
@export var rotation_rate: float = 15.0
@export var mouse_sensitivity: float = 0.0025
@export var iso_move_speed: float = 7.0   # click-to-move speed in isometric mode

@export_group("Jump")
@export var jump_height: float = 2.0
@export var coyote_time: float = 0.15
@export var jump_cooldown: float = 0.1

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 15.0
@export var regen_delay: float = 1.0

@export_group("Dodge")
@export var dodge_duration: float = 0.35
@export var dodge_iframe: float = 0.18
@export var dodge_speed_start: float = 20.0
@export var dodge_speed_end: float = 5.0
@export var chain_window: float = 1.0

@export_group("Attack")
@export var attack_damage: float = 25.0
@export var attack_duration: float = 0.45   # total swing time (movement is locked)
@export var attack_strike: float = 0.18     # when in the swing the hit is registered
@export var attack_range: float = 1.6       # forward reach of the hit sphere
@export var attack_radius: float = 1.0      # radius of the hit sphere

@export_group("Health")
@export var max_health: float = 100.0

const BUFFER_TIME := 0.15
const DODGE_COSTS := [20.0, 30.0,40.0]   # 1st / 2nd / 3rd+ in a chain
const ENEMY_LAYER := 4                    # physics layer 3 — enemy hurtboxes

@onready var model: Node3D = $Sketchfab_Scene
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var anim_tree: AnimationTree = $AnimTree
@onready var iso_camera: Camera3D = $IsoCamera

# HUD nodes (one shared HUD; only the local player binds to it). Resolved in
# _ready() from the scene root since players live under a Players container.
var stamina_bar: ProgressBar
var health_bar: ProgressBar
var mode_button: Button

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.81)
var _yaw: float = PI
var _pitch: float = -0.21
var _blend: float = 0.0

var _state: State = State.IDLE
var _sprinting: bool = false

# Input buffer (single slot).
var _buffer_cmd: String = ""
var _buffer_timer: float = 0.0

# Jump timers.
var _coyote: float = 0.0
var _jump_cd: float = 0.0

# Stamina.
var _stamina: float = 100.0
var _regen_timer: float = 0.0

# Dodge.
var _dodge_timer: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _invincible: bool = false
var _chain: int = 0
var _since_dodge: float = 999.0
var _air_dodge_used: bool = false   # one mid-air dodge until you land (GBF Relink style)

# Attack.
var _attack_timer: float = 0.0
var _attack_struck: bool = false

# Health.
var _health: float = 100.0

var _last_log: String = ""

# Camera / control mode.
var _cam_mode: CamMode = CamMode.TPS
var _move_target: Vector3 = Vector3.ZERO
var _has_target: bool = false


func _enter_tree() -> void:
	# Players are spawned named after the owning peer id (see gameplay.gd), so the
	# authority is consistent on every peer. A non-numeric name (running the scene
	# standalone) leaves the default authority so single-player still works.
	var id := str(name).to_int()
	if id > 0:
		set_multiplayer_authority(id)


func _ready() -> void:
	floor_snap_length = 0.3
	_stamina = max_stamina
	_health = max_health
	if not is_multiplayer_authority():
		# Remote player: no input/camera/HUD. The synchronizer drives position,
		# facing and the anim blend, so keep the AnimTree running and cameras off.
		camera.current = false
		iso_camera.current = false
		anim_tree.active = true
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var root := get_tree().current_scene
	if root:
		stamina_bar = root.get_node_or_null("HUD/StaminaBar")
		health_bar = root.get_node_or_null("HUD/HealthBar")
		mode_button = root.get_node_or_null("HUD/ModeButton")
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = _stamina
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = _health
	if mode_button:
		mode_button.pressed.connect(_toggle_mode)
	_apply_mode()


## Read by combat code: true during a dodge's i-frame window.
func is_invincible() -> bool:
	return _invincible


func take_damage(amount: float) -> void:
	if _invincible:
		return
	_health = clampf(_health - amount, 0.0, max_health)
	if health_bar:
		health_bar.value = _health
	# (defeat handling goes here once combat exists)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("toggle_mode"):
		_toggle_mode()
		return
	if _cam_mode == CamMode.TPS:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x * mouse_sensitivity
			_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.2, 0.4)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_buffer_cmd = "attack"
			_buffer_timer = BUFFER_TIME
		elif event.is_action_pressed("ui_cancel"):
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# ISO: right-click the ground to set a move target.
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_click_to_move(event.position)


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var target := atan2(dir.x, dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, target, 1.0 - exp(-rotation_rate * delta))


## Attempt to start (or chain) a dodge. Returns false (silently) if low on stamina.
func _try_dodge(move_dir: Vector3, has_input: bool) -> bool:
	var airborne := not is_on_floor()
	if airborne and _air_dodge_used:
		return false   # already used the mid-air dodge; must land first
	var cost: float = DODGE_COSTS[mini(_chain, DODGE_COSTS.size() - 1)]
	if _stamina < cost:
		return false
	_stamina -= cost
	_regen_timer = regen_delay
	_chain += 1
	_since_dodge = 0.0
	_state = State.DODGE
	_dodge_timer = dodge_duration
	_invincible = true
	if airborne:
		_air_dodge_used = true
	if has_input:
		_dodge_dir = move_dir
	else:
		_dodge_dir = Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))  # facing
	return true


func _start_attack() -> void:
	_state = State.ATTACK
	_attack_timer = attack_duration
	_attack_struck = false


## Sweep a sphere in front of the player and damage any enemy hurtboxes it overlaps.
## Damage is routed to the server (rpc_id 1); in offline solo it runs locally.
func _do_attack_strike() -> void:
	var facing := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var center := global_position + Vector3(0.0, 0.9, 0.0) + facing * attack_range
	var shape := SphereShape3D.new()
	shape.radius = attack_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), center)
	params.collision_mask = ENEMY_LAYER
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_shape(params, 16)
	var struck := {}
	for h in hits:
		var target: Node = h.collider.get_parent()   # hurtbox Area3D -> monster root
		if target and not struck.has(target) and target.has_method("take_damage"):
			struck[target] = true
			if multiplayer.multiplayer_peer == null:
				target.take_damage(attack_damage)        # offline solo: apply locally
			else:
				target.take_damage.rpc_id(1, attack_damage)  # route to the server


func _toggle_mode() -> void:
	_cam_mode = CamMode.ISO if _cam_mode == CamMode.TPS else CamMode.TPS
	_apply_mode()


func _apply_mode() -> void:
	_has_target = false
	if _cam_mode == CamMode.TPS:
		camera.current = true
		iso_camera.current = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if mode_button: mode_button.text = "Mode: TPS"
	else:
		iso_camera.current = true
		camera.current = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_state = State.IDLE
		velocity.x = 0.0
		velocity.z = 0.0
		if mode_button: mode_button.text = "Mode: ISO"


func _click_to_move(screen_pos: Vector2) -> void:
	var from := iso_camera.project_ray_origin(screen_pos)
	var dir := iso_camera.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit:
		_move_target = hit.position
		_has_target = true


func _physics_iso(delta: float) -> void:
	# Gravity + ground stick.
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -2.0
	else:
		velocity.y -= _gravity * delta

	# Move toward the clicked target, then stop.
	if _has_target:
		var to := _move_target - global_position
		to.y = 0.0
		if to.length() > 0.4:
			var dir := to.normalized()
			velocity.x = dir.x * iso_move_speed
			velocity.z = dir.z * iso_move_speed
			_face(dir, delta)
		else:
			_has_target = false
	if not _has_target:
		velocity.x = move_toward(velocity.x, 0.0, iso_move_speed)
		velocity.z = move_toward(velocity.z, 0.0, iso_move_speed)

	move_and_slide()

	# Stamina slowly refills in this mode.
	_regen_timer = maxf(_regen_timer - delta, 0.0)
	if _regen_timer <= 0.0:
		_stamina = minf(_stamina + stamina_regen * delta, max_stamina)
	if stamina_bar:
		stamina_bar.value = _stamina

	# Animation blend by actual speed.
	anim_tree.active = true
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var tb: float
	if hspeed <= 0.1:
		tb = 0.0
	elif hspeed <= walk_speed:
		tb = hspeed / walk_speed
	else:
		tb = 1.0 + (hspeed - walk_speed) / (sprint_speed - walk_speed)
	tb = clampf(tb, 0.0, 2.0)
	_blend = move_toward(_blend, tb, delta * 12.0)
	anim_tree.set("parameters/blend_position", _blend)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return   # remote players are moved by the MultiplayerSynchronizer
	if _cam_mode == CamMode.ISO:
		_physics_iso(delta)
		return
	spring_arm.rotation.y = _yaw
	spring_arm.rotation.x = _pitch

	# --- Buffer discrete inputs; toggle sprint immediately. ---
	if Input.is_action_just_pressed("jump"):
		_buffer_cmd = "jump"; _buffer_timer = BUFFER_TIME
	if Input.is_action_just_pressed("dodge"):
		_buffer_cmd = "dodge"; _buffer_timer = BUFFER_TIME
	if Input.is_action_just_pressed("sprint"):
		_sprinting = not _sprinting
	_buffer_timer -= delta
	if _buffer_timer <= 0.0:
		_buffer_cmd = ""

	# --- Timers. ---
	_jump_cd = maxf(_jump_cd - delta, 0.0)
	_since_dodge += delta
	if _since_dodge > chain_window:
		_chain = 0
	if is_on_floor():
		_coyote = coyote_time
		_air_dodge_used = false   # touching ground refreshes the air dodge
	else:
		_coyote = maxf(_coyote - delta, 0.0)

	# --- Gravity + ground stick. ---
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -2.0   # keep grounded on slopes
	else:
		velocity.y -= _gravity * delta

	# --- Variable jump height: releasing while rising cuts the jump. ---
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5

	# --- Camera-relative input direction. ---
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd := global_position - camera.global_position
	fwd.y = 0.0
	fwd = fwd.normalized()
	var rgt := fwd.cross(Vector3.UP).normalized()
	var move_dir := (fwd * -input.y + rgt * input.x)
	var has_input := move_dir.length() > 0.01
	if has_input:
		move_dir = move_dir.normalized()

	# --- Dodge trigger (from any non-dodge state). ---
	if _state != State.DODGE and _buffer_cmd == "dodge":
		_buffer_cmd = ""
		_try_dodge(move_dir, has_input)

	# --- Attack trigger (grounded; a buffered dodge can still cancel it). ---
	if _state != State.DODGE and _state != State.ATTACK and _buffer_cmd == "attack" and is_on_floor():
		_buffer_cmd = ""
		_start_attack()

	# --- Jump trigger (locked during dodge/attack). ---
	if _state != State.DODGE and _state != State.ATTACK and _buffer_cmd == "jump" and _coyote > 0.0 and _jump_cd <= 0.0:
		_buffer_cmd = ""
		velocity.y = sqrt(2.0 * _gravity * jump_height)
		_jump_cd = jump_cooldown
		_coyote = 0.0
		_state = State.JUMP

	if _state == State.DODGE:
		# Forced burst with linear deceleration 20 -> 5.
		_dodge_timer -= delta
		var tnorm := clampf(1.0 - _dodge_timer / dodge_duration, 0.0, 1.0)
		var spd := lerpf(dodge_speed_start, dodge_speed_end, tnorm)
		velocity.x = _dodge_dir.x * spd
		velocity.z = _dodge_dir.z * spd
		_invincible = (dodge_duration - _dodge_timer) < dodge_iframe
		_face(_dodge_dir, delta)
		if _dodge_timer <= 0.0:
			_invincible = false
			if _buffer_cmd == "dodge" and _try_dodge(move_dir, has_input):
				pass  # chained into another dodge
			elif not is_on_floor():
				_state = State.JUMP
			else:
				_state = State.MOVE if has_input else State.IDLE
	elif _state == State.ATTACK:
		# Grounded swing: hold position while it plays. The hit lands once at
		# `attack_strike`; a buffered dodge (handled above) can cancel it early.
		_attack_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
		_face(move_dir, delta)
		if not _attack_struck and (attack_duration - _attack_timer) >= attack_strike:
			_attack_struck = true
			_do_attack_strike()
		if _attack_timer <= 0.0:
			_state = State.MOVE if has_input else State.IDLE
	else:
		# Walk / sprint with smooth acceleration; full air control.
		var target_speed := 0.0
		if has_input:
			target_speed = sprint_speed if _sprinting else walk_speed
		var target_vel := move_dir * target_speed
		var hv := Vector3(velocity.x, 0.0, velocity.z)
		# Accelerate smoothly, but stop crisply so there is no forward slide.
		var smooth := accel_time if has_input else stop_time
		hv = hv.lerp(target_vel, 1.0 - exp(-delta / maxf(smooth, 0.0001)))
		if not has_input and hv.length() < 0.4:
			hv = Vector3.ZERO
		velocity.x = hv.x
		velocity.z = hv.z
		_face(move_dir, delta)
		if not is_on_floor():
			_state = State.JUMP
		else:
			_state = State.MOVE if has_input else State.IDLE

	move_and_slide()

	# --- Stamina regen (only dodge consumes; sprint is free). ---
	if _state != State.DODGE:
		_regen_timer = maxf(_regen_timer - delta, 0.0)
		if _regen_timer <= 0.0:
			_stamina = minf(_stamina + stamina_regen * delta, max_stamina)
	if stamina_bar:
		stamina_bar.value = _stamina

	# --- Animation: freeze during dodge/attack; else blend idle/walk/run by intent. ---
	if _state == State.DODGE or _state == State.ATTACK:
		anim_tree.active = false
	else:
		anim_tree.active = true
		# Drive the blend by what the player is INPUTTING, not the decaying velocity,
		# so releasing the stick snaps to idle immediately (no run-anim tail).
		var intend := 0.0
		if has_input:
			intend = sprint_speed if _sprinting else walk_speed
		var tb: float
		if intend <= walk_speed:
			tb = intend / walk_speed
		else:
			tb = 1.0 + (intend - walk_speed) / (sprint_speed - walk_speed)
		tb = clampf(tb, 0.0, 2.0)
		_blend = move_toward(_blend, tb, delta * 14.0)
		anim_tree.set("parameters/blend_position", _blend)

	_log_state()


func _log_state() -> void:
	var names := ["idle", "move", "jump", "dodge", "attack"]
	var label: String = names[_state]
	if _state == State.MOVE and _sprinting:
		label = "sprint"
	if label != _last_log:
		_last_log = label
		var iframe := "  [I-FRAME]" if _invincible else ""
		print("[STATE] %-6s | stam %3.0f | hp %3.0f | chain %d%s" % [label, _stamina, _health, _chain, iframe])
