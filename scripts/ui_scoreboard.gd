extends Patch9Frame

onready var pfb_sbItem = load("res://prefabs/ui_sbItem.tscn");

var items = {};
var container;

func _ready():
	items.clear();
	container = get_node("container");
	
	hide();
	set_process_input(true);

func _input(ie):
	if (ie.type == InputEvent.KEY && ie.scancode == KEY_TAB):
		set_hidden(!ie.pressed);

func sync_item(id):
	if (!get_tree().is_network_server()):
		return;
	
	for i in items.keys():
		rpc_id(id, "add_item", i, items[i].name, items[i].kill, items[i].death);

sync func add_item(id, name = "Unnamed", kill = 0, death = 0):
	var item = pfb_sbItem.instance();
	item.set_name(str(id));
	container.add_child(item);
	
	items[id] = {
		'item': item,
		'name': name,
		'kill': kill,
		'death': death
	};
	
	set_clname(id, name);
	set_kill(id, kill);
	set_death(id, death);

sync func remove_item(id):
	if (!items.has(id)):
		return;
	items.erase(id);

sync func set_clname(id, val):
	if (!items.has(id)):
		return;
	items[id].name = val;
	items[id].item.get_node("lblName").set_text(str(val));

sync func set_kill(id, val):
	if (!items.has(id)):
		return;
	items[id].kill = val;
	items[id].item.get_node("lblKill").set_text(str(int(val)));

sync func set_death(id, val):
	if (!items.has(id)):
		return;
	items[id].death = val;
	items[id].item.get_node("lblDeath").set_text(str(int(val)));

func increment_kill(id, increment):
	if (!get_tree().is_network_server()):
		return;
	
	items[id].kill += increment;
	rpc("set_kill", id, items[id].kill);
