extends Node

const API_URL = "http://localhost/opencombat/server.php";

onready var gui = get_node("gui");
onready var env = get_node("env");
onready var masterServer = get_node("masterServer");
onready var mainCam = get_node("mainCamera");
onready var players = get_node("players");

var time = 0.0;
var udp = PacketPeerUDP.new();

var cl_name = "Player";
var playerList = {};
var pfb_player = "res://prefabs/player.tscn";

func _ready():
	OS.set_target_fps(30);
	
	get_tree().connect("network_peer_connected", self, "_peer_connected");
	get_tree().connect("network_peer_disconnected", self, "_peer_disconnected");
	
	get_tree().connect("connected_to_server", self, "_client_success");
	get_tree().connect("connection_failed", self, "_client_failed");
	get_tree().connect("server_disconnected", self, "_client_disconnected");
	
	gui.ui_inGame.hide();
	gui.ui_gameManager.show();
	
	pfb_player = load(pfb_player);
	
	mainCam.make_current();
	
	set_process(true);
	set_process_input(true);

func _process(delta):
	time += delta;
	
	while (udp.get_available_packet_count() > 0):
		var packet = udp.get_var();
		var ip = udp.get_packet_ip();
		var port = udp.get_packet_port();
		
		udp.set_send_address(ip, port);
		udp.put_var([packet, playerList.size(), 32]);

func _input(ie):
	if (ie.type == InputEvent.KEY && ie.pressed):
		if (ie.scancode == KEY_ESCAPE):
			if (Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE);
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);
		
		if (ie.scancode == KEY_F1):
			OS.set_window_fullscreen(!OS.is_window_fullscreen());
		
		if (ie.scancode == KEY_F2):
			OS.set_window_maximized(!OS.is_window_maximized());

func create_game(port, maxClients = 32):
	var peer = NetworkedMultiplayerENet.new();
	
	if (peer.create_server(port, maxClients) != OK):
		print("Cannot create a server on port ", port, "!");
		return;
	
	get_tree().set_network_peer(peer);
	
	if (udp.listen(port+1) != OK):
		print("Cannot bind peer on port "+str(port+1)+"!");
		return;
	
	time = 0.0;
	cl_name = gui.ui_gameManager.get_node("inName").get_text();
	
	var serverName = gui.ui_gameManager.get_node("inServerName").get_text().percent_encode();
	masterServer.register_server(port, serverName);
	
	init_game();

func join_game(ip, port, password = ""):
	var peer = NetworkedMultiplayerENet.new();
	
	if (peer.create_client(ip, port) != OK):
		print("Cannot create a client on ip ", ip, " & port ", port, "!");
		return;
	
	get_tree().set_network_peer(peer);
	
	time = 0.0;
	cl_name = gui.ui_gameManager.get_node("inName").get_text();
	
	print("Connecting to ", ip, ":", port, "..");

# Server callbacks
func _peer_connected(id):
	if (!get_tree().is_network_server()):
		return;
	
	playerList[id] = null;

func _peer_disconnected(id):
	if (!get_tree().is_network_server()):
		return;
	
	if (playerList.has(id)):
		_player_disconnected(id);
		playerList.erase(id);

master func _player_joined(id, name):
	if (!get_tree().is_network_server()):
		return;
	
	if (!playerList.has(id)):
		return;
	
	rpc_id(id, "init_game");
	gui.ui_scoreBoard.sync_item(id);
	
	rpc("create_player", id, name);
	
	for i in playerList.keys():
		if (i == id):
			continue;
		rpc_id(id, "create_player", i, name);

func _player_disconnected(id):
	rpc("destroy_player", id);

# Client callbacks
func _client_success():
	rpc("_player_joined", get_tree().get_network_unique_id(), cl_name);
	gui.ui_gameManager.hide();
	gui.ui_inGame.show();

func _client_failed():
	print("Failed connecting to the server.");
	gui.ui_gameManager.show();
	gui.ui_inGame.hide();

func _client_disconnected():
	print("Disconnected from server.");
	
	destroy_game();
	
	gui.ui_gameManager.show();
	gui.ui_inGame.hide();

func init_game():
	destroy_game();
	
	gui.ui_gameManager.hide();
	gui.ui_inGame.show();
	
	gui.ui_scoreBoard.clear_items();
	
	if (get_tree().is_network_server()):
		create_player(get_tree().get_network_unique_id(), cl_name);

sync func create_player(id, name):
	var inst = pfb_player.instance();
	inst.set_name(str(id));
	inst.player_id = id;
	inst.player_name = name;
	
	if (get_tree().get_network_unique_id() == id):
		inst.set_network_mode(NETWORK_MODE_MASTER);
	else:
		inst.set_network_mode(NETWORK_MODE_SLAVE);
	
	players.add_child(inst);
	playerList[id] = inst;

sync func destroy_game():
	for i in players.get_children():
		i.queue_free();

sync func destroy_player(id):
	if (get_tree().is_network_server() && !playerList.has(id)):
		return;
	var node = players.get_node(str(id));
	if (!node):
		return;
	node.queue_free();

func playerByID(id):
	if (!playerList.has(id)):
		return null;
	
	return playerList[id];
