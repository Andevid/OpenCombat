extends Spatial

var target = null;
var startPos = Vector3();
var yaw = 0;
var camera = null;
var curRange = 0.0;
var maxRange = 3.0;

func _ready():
	camera = get_node("camera");
	camera.make_current();
	
	set_process(true);

func _process(delta):
	var pos = startPos;
	var pitch = 0;
	
	curRange = lerp(curRange, maxRange, 5*delta);
	
	pos.x += curRange*sin(deg2rad(yaw))*cos(deg2rad(pitch));
	pos.y += curRange*sin(deg2rad(pitch));
	pos.z += curRange*cos(deg2rad(yaw))*cos(deg2rad(pitch));
	
	set_translation(pos);
	
	if (target != null && weakref(target).get_ref()):
		look_at(target.get_global_transform().origin, Vector3(0,1,0));
