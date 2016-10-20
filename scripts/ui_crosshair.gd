extends Control

export var DRAW_DOT = true;
export var DRAW_LINE = true;
export var DRAW_CIRCLE = true;

var ch_size = 16.0;
var cur_size = 0.0;

func _ready():
	set_process(true);

func _process(delta):
	cur_size = max(cur_size-(cur_size*delta*2), ch_size);

	update();

func _draw():
	var start_pos = get_size()/2;
	var line = 4;
	var line_rot = 0.0;
	var size = cur_size;
	var line_size = clamp(size/2.0, 8.0, 64.0);
	var dist = size/8.0;
	var color = Color(0,1,0);

	if (DRAW_DOT):
		draw_rect(Rect2(start_pos-Vector2(1,1), Vector2(2,2)), color);

	if (DRAW_LINE):
		for i in range(line):
			var start = start_pos;
			start.x += sin(deg2rad(line_rot+360/line*i))*(size+line_size/2);
			start.y += cos(deg2rad(line_rot+360/line*i))*(size+line_size/2);

			var end = start_pos;
			end.x += sin(deg2rad(line_rot+360/line*i))*(size-line_size/2);
			end.y += cos(deg2rad(line_rot+360/line*i))*(size-line_size/2);

			draw_line(start, end, color, 1.0);

	if (DRAW_CIRCLE):
		for i in range(360/dist):
			var start = start_pos;
			start.x += sin(deg2rad(i*dist))*size;
			start.y += cos(deg2rad(i*dist))*size;

			var end = start_pos;
			end.x += sin(deg2rad(i*dist+dist))*size;
			end.y += cos(deg2rad(i*dist+dist))*size;

			draw_line(start, end, color, 1.0);

func apply_firing():
	cur_size = clamp(cur_size+4.0, 16.0, 32.0);

func set_ch_size(size):
	ch_size = size;
