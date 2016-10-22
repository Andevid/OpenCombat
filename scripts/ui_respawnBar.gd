extends Patch9Frame

var spawnTime = 0.0;
var timeLeft = 0.0;
var progBar;

func _ready():
	progBar = get_node("ProgressBar");
	hide();

func draw_spawnBar(time):
	show();
	progBar.set_value(100.0);
	
	spawnTime = time;
	timeLeft = time;
	
	set_process(true);

func _process(delta):
	if (timeLeft > 0.0):
		timeLeft -= delta;
		progBar.set_value((spawnTime-timeLeft)/spawnTime*100.0);
	else:
		hide();
		set_process(false);
