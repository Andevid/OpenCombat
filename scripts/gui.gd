extends Control

onready var ui_gameManager	= get_node("ui_gameManager");
onready var ui_inGame		= get_node("ui_inGame");
onready var ui_lblFPS		= get_node("lblFPS");

onready var ui_rayHit		= ui_inGame.get_node("ui_rayHit");
onready var ui_crosshair	= ui_inGame.get_node("ui_crosshair");
onready var ui_minimap		= ui_inGame.get_node("ui_minimap");
onready var ui_lblHealth	= ui_inGame.get_node("ui_playerInfo/health/lblHealth");
onready var ui_lblAmmo		= ui_inGame.get_node("ui_playerInfo/ammunition/lblAmmo");
onready var ui_scoreBoard	= ui_inGame.get_node("ui_scoreBoard");
onready var ui_spawnBar		= ui_inGame.get_node("respawnBar");

onready var fx_bloodOverlay	= ui_inGame.get_node("fx_bloodoverlay/AnimationPlayer");

func _ready():
	set_process(true);

func _process(delta):
	ui_lblFPS.set_text("FPS: "+str(OS.get_frames_per_second()));

func fx_bloodOverlay():
	fx_bloodOverlay.play("start");
