extends Patch9Frame

const API_URL = "http://localhost/opencombat/server.php";

onready var game = get_node("/root/game");
onready var container = get_node("server/container");
onready var pfb_srvListItem = load("res://prefabs/ui_srvListItem.tscn");

var udp = PacketPeerUDP.new();

var listingQueue = {};

func _ready():	
	randomize();
	var udpPort = int(rand_range(25000, 25100));
	if (udp.listen(udpPort) != OK):
		print("Cannot bind peer on port "+str(udpPort)+"!");
		return;
	
	get_node("btnRefresh").connect("pressed", self, "refreshServer");
	get_node("btnHost").connect("pressed", self, "hostServer");
	get_node("btnConnect").connect("pressed", self, "connectServer");
	
	set_process(true);

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
	
	if (!game.masterServer.is_connected("server_retrieved", self, "on_server_retrieved")):
		game.masterServer.connect("server_retrieved", self, "on_server_retrieved");
	
	game.masterServer.retrieve_server();

func hostServer():
	var port = get_node("inPort").get_text().to_int();
	var maxClients = 32;
	
	game.create_game(port, maxClients);

func connectServer():
	var ip = get_node("inIP").get_text();
	var port = get_node("inPort").get_text().to_int();
	var password = get_node("inPass").get_text();
	
	game.join_game(ip, port, password);

func on_server_retrieved(servers):
	get_node("btnRefresh").set_disabled(false);
	
	listingQueue.clear();
	
	for i in container.get_children():
		i.queue_free();
	
	var id = 1;
	
	for i in servers.result:
		listingQueue[id] = [i.name, i.ip, i.port.to_int(), true, game.time];
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
