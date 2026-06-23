extends Node
## Transport layer for co-op: ENet, direct IP, client-authoritative, up to 3 players.
##
## This singleton only creates / tears down the multiplayer peer. Spawning players
## and reacting to connections is done in gameplay.gd, which listens to the standard
## `multiplayer.*` signals. Star topology with the default `server_relay` means each
## client's MultiplayerSynchronizer reaches the others through the host.

const PORT := 24565
const MAX_PLAYERS := 4            # total players, including the host
const DEFAULT_IP := "127.0.0.1"


func host(port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	# create_server's max_clients excludes the host, so subtract one.
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func join(ip: String = DEFAULT_IP, port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
