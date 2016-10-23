extends Spatial

var target = null;
var startPos = Vector3();
var camera = null;
var curRange = 0.0;
var maxRange = 2.0;
var nextObserve = 0.0;

func _ready():
	camera = get_node("camera");
	camera.make_current();
	
	nextObserve = 5.0;
	
	set_process(true);

func _process(delta):
	var pos = startPos;
	curRange = lerp(curRange, maxRange, 1*delta);
	nextObserve = max(nextObserve-delta, 0.0);
	
	if (nextObserve <= 0.0 && target != null && weakref(target).get_ref()):
		var targetPos = target.get_global_transform().origin+Vector3(0,1.5,0);
		var targetYaw = target.yaw;
		var pitch = 30.0;
		
		pos = targetPos;
		pos.x += (curRange)*sin(deg2rad(targetYaw))*cos(deg2rad(pitch));
		pos.y += (curRange)*sin(deg2rad(pitch));
		pos.z += (curRange)*cos(deg2rad(targetYaw))*cos(deg2rad(pitch));
		
		var trans = Transform();
		trans.origin = pos;
		trans = trans.looking_at(targetPos, Vector3(0,1,0));
		
		set_global_transform(trans);
	else:
		pos.y += curRange;
		
		set_translation(pos);
		
		if (target != null && weakref(target).get_ref()):
			look_at(target.get_global_transform().origin, Vector3(0,1,0));
