extends Node

var connected_peers: Array[int] = []
var is_host := false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func host_game(port: int = 9999) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, 3)
	if err != OK:
		push_error("Failed to create server: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	connected_peers.append(1)
	print("Hosting on port %d" % port)
	return OK

func join_game(address: String, port: int = 9999) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		push_error("Failed to connect: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	print("Joining %s:%d" % [address, port])
	return OK

func disconnect_game() -> void:
	multiplayer.multiplayer_peer = null
	connected_peers.clear()
	is_host = false

func get_all_peer_ids() -> Array[int]:
	var ids: Array[int] = [1]  # Host is always 1
	for pid in connected_peers:
		if pid != 1 and pid not in ids:
			ids.append(pid)
	return ids

func _on_peer_connected(peer_id: int) -> void:
	if peer_id not in connected_peers:
		connected_peers.append(peer_id)
	print("Peer connected: %d (total: %d)" % [peer_id, connected_peers.size()])
	EventBus.player_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	connected_peers.erase(peer_id)
	print("Peer disconnected: %d" % peer_id)
	EventBus.player_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	print("Connected to server as peer %d" % my_id)
	EventBus.player_connected.emit(my_id)

func _on_connection_failed() -> void:
	push_error("Connection failed")
	multiplayer.multiplayer_peer = null
