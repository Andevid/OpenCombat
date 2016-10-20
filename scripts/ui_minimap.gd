extends Control

onready var frame = get_node("tex");
onready var viewport = get_node("vp");
onready var camera = get_node("vp/cam");
onready var vp_obj = get_node("vp/objects");

onready var pfb_viewcone = load("res://prefabs/ui_mmViewcone.tscn");

var pos = Vector3();
var rot = 0.0;
var scaling = 10.909090909;
var objects = {};

func _ready():
	viewport.set_rect(get_rect());
	
	set_process(true);

func _process(delta):
	camera.set_rot(deg2rad(rot));
	camera.set_pos(Vector2(pos.x, pos.z)*scaling);
	
	for i in objects:
		var spr = objects[i][0];
		var obj = objects[i][1];
		var rot = 0.0;
		var pos = Vector2(0, 0);
		
		if (obj extends Spatial):
			rot = obj.get_rotation().y;
			pos = obj.get_global_transform().origin;
			pos = Vector2(pos.x, pos.z);
			
			if (obj extends preload("res://scripts/player.gd")):
				rot = deg2rad(obj.yaw);
		if (obj extends Node2D):
			rot = obj.get_rot();
			pos = obj.get_pos();
		
		spr.set_rot(rot);
		spr.set_pos(pos*scaling);
	
	frame.set_texture(viewport.get_render_target_texture());

func add_object(obj):
	var inst = pfb_viewcone.instance();
	inst.set_name(obj.get_name());
	vp_obj.add_child(inst);
	
	objects[obj.get_name()] = [inst, obj];

func remove_object(obj):
	if (!objects.has(obj.get_name())):
		return;
	
	objects[obj.get_name()][0].queue_free();
	objects.erase(obj.get_name());
