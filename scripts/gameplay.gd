extends Node3D
## Co-op session controller.
##
## Wires the Host/Join menu to NetworkManager and spawns a player per peer. Only the
## server instantiates players (the MultiplayerSpawner replicates them to every
## client); each player node becomes client-authoritative once it exists, via the
## name-based authority set in player.gd's _enter_tree.

@export var player_scene: PackedScene

const MONSTER_SCENE := preload("res://scenes/dummy.tscn")

# Spread spawn points (a square) so co-op players don't overlap — one per player.
const SPAWN_POINTS := [
	Vector3(2.0, 1.0, 2.0),
	Vector3(-2.0, 1.0, 2.0),
	Vector3(2.0, 1.0, -2.0),
	Vector3(-2.0, 1.0, -2.0),
]

# Where training dummies stand. Spawned by the server (the MultiplayerSpawner
# replicates them) or directly in single-player.
const MONSTER_SPAWNS := [
	Vector3(0.0, 0.0, -6.0),
	Vector3(4.0, 0.0, -6.0),
	Vector3(-4.0, 0.0, -6.0),
]

@onready var _net: Node = get_node("/root/NetworkManager")
@onready var players: Node3D = $Players
@onready var monsters: Node3D = $Monsters
@onready var menu: Control = $NetworkUI/Menu
@onready var status: Label = $NetworkUI/Menu/Panel/VBox/Status
@onready var ip_field: LineEdit = $NetworkUI/Menu/Panel/VBox/IP
@onready var host_btn: Button = $NetworkUI/Menu/Panel/VBox/HostButton
@onready var join_btn: Button = $NetworkUI/Menu/Panel/VBox/JoinButton
@onready var solo_btn: Button = $NetworkUI/Menu/Panel/VBox/SoloButton


func _ready() -> void:
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	solo_btn.pressed.connect(_on_solo)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Menu actions ---

func _on_host() -> void:
	if _net.host() == OK:
		_start_as_server()
	else:
		status.text = "Host failed (port %d busy?)" % _net.PORT


func _on_solo() -> void:
	# Single-player needs no networking — spawn a local player directly so it works
	# even when the co-op port is busy (e.g. another instance is already hosting).
	menu.hide()
	_spawn_world()
	_spawn_player(1)


func _on_join() -> void:
	var ip := ip_field.text.strip_edges()
	if ip.is_empty():
		ip = _net.DEFAULT_IP
	if _net.join(ip) == OK:
		status.text = "Connecting to %s ..." % ip
		_set_buttons_enabled(false)
	else:
		status.text = "Join failed"


func _start_as_server() -> void:
	menu.hide()
	_spawn_world()
	_spawn_player(multiplayer.get_unique_id())   # host's own player (id 1)


# --- Connection signal handlers ---

func _on_connected() -> void:
	menu.hide()                                   # client reached the host


func _on_connection_failed() -> void:
	_net.leave()
	status.text = "Connection failed"
	_set_buttons_enabled(true)


func _on_server_disconnected() -> void:
	_clear_players()
	_net.leave()
	status.text = "Server closed"
	_set_buttons_enabled(true)
	menu.show()


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(id)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		var node := players.get_node_or_null(str(id))
		if node:
			node.queue_free()


# --- Spawning ---

func _spawn_player(id: int) -> void:
	if players.has_node(str(id)):
		return
	var idx := clampi(players.get_child_count(), 0, SPAWN_POINTS.size() - 1)
	var p := player_scene.instantiate()
	p.name = str(id)                              # authority is derived from this name
	p.position = SPAWN_POINTS[idx]
	players.add_child(p)                           # MultiplayerSpawner replicates it


## Server/solo only: place the training dummies once. The MultiplayerSpawner on
## $Monsters replicates them to clients (and to late-joiners).
func _spawn_world() -> void:
	if monsters.get_child_count() > 0:
		return
	for i in MONSTER_SPAWNS.size():
		var m := MONSTER_SCENE.instantiate()
		m.name = "Dummy%d" % i
		m.position = MONSTER_SPAWNS[i]
		monsters.add_child(m)


func _clear_players() -> void:
	for c in players.get_children():
		c.queue_free()
	for c in monsters.get_children():
		c.queue_free()


func _set_buttons_enabled(on: bool) -> void:
	host_btn.disabled = not on
	join_btn.disabled = not on
	solo_btn.disabled = not on
