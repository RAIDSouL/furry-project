extends StaticBody3D
## Training dummy — a server-authoritative target that takes damage and respawns.
##
## Damage is applied only on the authority (the server, or the local peer in offline
## single-player) via the take_damage RPC; `_health` is replicated by the
## MultiplayerSynchronizer so every peer shows the same HP and the same hit flash.
## When HP reaches zero the dummy hides/disables itself for `respawn_delay`, then the
## authority restores full HP (which syncs the dummy back in for everyone).

@export var max_health: float = 100.0
@export var respawn_delay: float = 3.0

const BAR_WIDTH := 1.0
const BODY_COLOR := Color(0.82, 0.42, 0.42)
const FLASH_TIME := 0.18

# Replicated by the Synchronizer (authority -> everyone).
var _health: float = 100.0

# Local-only presentation / authority bookkeeping.
var _prev_health: float = 100.0
var _flash: float = 0.0
var _down: bool = false
var _respawn: float = 0.0
var _mat: StandardMaterial3D

@onready var mesh: MeshInstance3D = $Mesh
@onready var body_collision: CollisionShape3D = $BodyCollision
@onready var hurtbox: Area3D = $Hurtbox
@onready var bar: Node3D = $HealthBar
@onready var bar_fill: MeshInstance3D = $HealthBar/Fill
@onready var bar_bg: MeshInstance3D = $HealthBar/BG


func _ready() -> void:
	_health = max_health
	_prev_health = _health
	add_to_group("monsters")

	# Per-instance body material so the hit flash doesn't tint every dummy.
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = BODY_COLOR
	mesh.material_override = _mat

	bar_bg.material_override = _bar_material(Color(0.0, 0.0, 0.0, 0.6))
	bar_fill.material_override = _bar_material(Color(0.32, 0.9, 0.42, 1.0))


func _bar_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	return m


## Called by an attacker via take_damage.rpc_id(1, amount). Only the authority
## mutates HP; in offline solo the RPC just runs locally (we are our own authority).
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float) -> void:
	if not _is_authority():
		return
	if _health <= 0.0:
		return   # already down / respawning
	_health = clampf(_health - amount, 0.0, max_health)
	if _health <= 0.0:
		_down = true
		_respawn = respawn_delay


func _is_authority() -> bool:
	return multiplayer.multiplayer_peer == null or is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	# Authority runs the respawn timer; restoring _health syncs the dummy back in.
	if _is_authority() and _down:
		_respawn -= delta
		if _respawn <= 0.0:
			_down = false
			_health = max_health


func _process(delta: float) -> void:
	# Hit flash fires on the frame the synced HP drops — so it shows on every peer.
	if _health < _prev_health:
		_flash = FLASH_TIME
	_prev_health = _health
	_flash = maxf(_flash - delta, 0.0)

	# Alive state is derived from the synced HP (no extra property to replicate).
	var alive := _health > 0.0
	mesh.visible = alive
	bar.visible = alive
	body_collision.disabled = not alive
	hurtbox.monitorable = alive
	if not alive:
		return

	_mat.albedo_color = BODY_COLOR.lerp(Color.WHITE, _flash / FLASH_TIME) if _flash > 0.0 else BODY_COLOR

	# HP bar: fill shrinks toward the left edge, billboarded (yaw-only) to the camera.
	var ratio := _health / max_health
	bar_fill.scale.x = maxf(ratio, 0.001)
	bar_fill.position.x = -(1.0 - ratio) * BAR_WIDTH * 0.5
	var cam := get_viewport().get_camera_3d()
	if cam:
		var look := cam.global_position
		look.y = bar.global_position.y
		if not bar.global_position.is_equal_approx(look):
			bar.look_at(look, Vector3.UP)
			bar.rotate_object_local(Vector3.UP, PI)   # face toward the camera, not away
