extends Spatial

var time = 0.0;
var particle;

func _ready():
	particle = get_node("Particles");
	
	var scale = rand_range(0.6,1.4);
	get_node("Quad").set_scale(Vector3(1,1,1)*scale);
	
	set_process(true);

func _process(delta):
	time += delta;
	
	if time > 0.1 && particle.is_emitting():
		particle.set_emitting(false);
	
	if time > 5.0:
		queue_free();
		set_process(false);
