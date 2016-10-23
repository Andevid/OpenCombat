extends Patch9Frame

const API_URL = "http://localhost/opencombat/server.php";

onready var game = get_node("/root/game");
onready var container = get_node("server/container");
onready var pfb_srvListItem = load("res://prefabs/ui_srvListItem.tscn");

var http = HTTPRequest.new();
var udp = PacketPeerUDP.new();

var listingQueue = {};

func _ready():
	http.set_use_threads(true);
	http.connect("request_completed", self, "on_serverRequest_completed");
	add_child(http);
	
	randomize();
	var udpPort = int(rand_range(25000, 25100));
	if (udp.listen(udpPort) != OK):
		print("Cannot bind peer on port "+str(udpPort)+"!");
		return;
	
	get_node("btnRefresh").connect("pressed", self, "refreshServer");
	get_node("btnHost").connect("pressed", self, "hostServer");
	get_node("btnConnect").connect("pressed", self, "connectServer");
	
	set_process(true);
	
	refreshServer();

func _process(delta):
	while (udp.get_available_packet_count() > 0):
		var packet = udp.get_var();
		var id = packet[0];
		if (listingQueue.has(id)):
			var identity = listingQueue[id];
			var data = [packet[1], packet[2]];
			add_item(identity, data);
			listingQueue.erase(id);

func refreshServer():
	get_node("btnRefresh").set_disabled(true);
	
	http.cancel_request();
	http.request(game.API_URL+"?do=lists");

func hostServer():
	http.cancel_request();
	
	var port = get_node("inPort").get_text().to_int();
	var maxClients = 32;
	
	game.create_game(port, maxClients);

func connectServer():
	http.cancel_request();
	
	var ip = get_node("inIP").get_text();
	var port = get_node("inPort").get_text().to_int();
	var password = get_node("inPass").get_text();
	
	game.join_game(ip, port, password);

func on_serverRequest_completed(result, response, headers, body):
	get_node("btnRefresh").set_disabled(false);
	
	if (result != HTTPRequest.RESULT_SUCCESS):
		return;
	
	var text = body.get_string_from_utf8();
	var json = {};
	json.parse_json(text);
	
	if (json.empty() || json.status != 'ok'):
		return;
	
	listingQueue.clear();
	
	for i in container.get_children():
		i.queue_free();
	
	var id = 1;
	
	for i in json.result:
		listingQueue[id] = [str(id, ". ")+i.name, i.ip, i.port.to_int(), i.password, game.time];
		udp.set_send_address(i.ip, i.port.to_int()+1);
		udp.put_var(id);
		id += 1;

func add_item(identity, data):
	var inst = pfb_srvListItem.instance();
	inst.connManager = self;
	inst.srvName = identity[0];
	inst.srvIP = identity[1];
	inst.srvPort = identity[2];
	inst.srvPassword = identity[3];
	inst.srvLatency = game.time-identity[4];
	inst.srvPlayers = [data[0], data[1]];
	inst.update_node();
	container.add_child(inst);

func item_pressed(item):
	game.join_game(item.srvIP, item.srvPort, item.srvPassword);
