extends Node

onready var gui		= get_node("gui");
onready var env		= get_node("env");
onready var mainCam	= get_node("mainCamera");
onready var players	= get_node("players");

var time = 0.0;

var cl_name = "Player";

var sv_players = {};

var pfb_player = "res://prefabs/player.tscn";

func _ready():
	OS.set_target_fps(30);
	
	get_tree().connect("network_peer_connected", self, "_peer_connected");
	get_tree().connect("network_peer_disconnected", self, "_peer_disconnected");
	
	get_tree().connect("connected_to_server", self, "_client_success");
	get_tree().connect("connection_failed", self, "_client_failed");
	get_tree().connect("server_disconnected", self, "_client_disconnected");
	
	gui.ui_gameManager.get_node("btnHost").connect("pressed", self, "create_game");
	gui.ui_gameManager.get_node("btnConnect").connect("pressed", self, "join_game");
	
	gui.ui_inGame.hide();
	gui.ui_gameManager.show();
	
	pfb_player = load(pfb_player);
	
	mainCam.make_current();
	
	set_process(true);
	set_process_input(true);

func _process(delta):
	time += delta;

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

func create_game():
	var peer = NetworkedMultiplayerENet.new();
	var port = gui.ui_gameManager.get_node("inPort").get_text().to_int();
	var max_clients = 32;
	
	if (peer.create_server(port, max_clients) != OK):
		print("Cannot create a server on port ", port, "!");
		return;
	
	get_tree().set_network_peer(peer);
	
	time = 0.0;
	cl_name = gui.ui_gameManager.get_node("inName").get_text();
	
	init_game();

func join_game():
	var peer = NetworkedMultiplayerENet.new();
	var ip = gui.ui_gameManager.get_node("inIP").get_text();
	var port = gui.ui_gameManager.get_node("inPort").get_text().to_int();
	
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
	
	sv_players[id] = null;

func _peer_disconnected(id):
	if (!get_tree().is_network_server()):
		return;
	
	if (sv_players.has(id)):
		_player_disconnected(id);
		sv_players.erase(id);

master func _player_joined(id, name):
	if (!get_tree().is_network_server()):
		return;
	
	if (!sv_players.has(id)):
		return;
	
	rpc_id(id, "init_game");
	gui.ui_scoreBoard.sync_item(id);
	
	rpc("create_player", id, name);
	
	for i in sv_players.keys():
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
	
	if (get_tree().is_network_server()):
		sv_players[id] = inst;

sync func destroy_game():
	for i in players.get_children():
		i.queue_free();

sync func destroy_player(id):
	if (get_tree().is_network_server() && !sv_players.has(id)):
		return;
	var node = players.get_node(str(id));
	if (!node):
		return;
	node.queue_free();
