extends Button

var connManager = null;
var srvName = "";
var srvIP = "";
var srvPort = 0;
var srvPassword = 0;
var srvLatency = 0;
var srvPlayers = [0, 0];

func _ready():
	connect("pressed", self, "on_pressed");

func on_pressed():
	connManager.item_pressed(self);

func update_node():
	set_text(str(srvName, " (", srvPlayers[0], "/", srvPlayers[1], ") (", int(srvLatency*1000), "ms)"));
