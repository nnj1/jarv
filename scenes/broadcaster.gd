# Broadcaster.gd
extends Timer

var broadcaster := PacketPeerUDP.new()
var listen_port := 8910
var server_info := {"name": GameManager.game_name, "port": GameManager.current_port, "players": 1}

func _ready():
	# 1. Safety Check: Only the host should broadcast
	if not multiplayer.is_server():
		stop() # Ensure timer isn't running
		return

	# 2. Setup UDP
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address("255.255.255.255", listen_port)
	
	# 3. Connect the timer's own timeout signal to itself
	self.timeout.connect(_on_timeout)
	
	# 4. Start the loop (e.g., every 2 seconds)
	wait_time = 2.0
	start()

func _on_timeout():
	# Double check server status in case ownership changed
	if multiplayer.is_server():
		server_info["players"] = multiplayer.get_peers().size() + 1
		var data = JSON.stringify(server_info)
		broadcaster.put_packet(data.to_utf8_buffer())
		print('Just broadcasted server...')
