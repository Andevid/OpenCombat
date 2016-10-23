extends RigidBody

const SPEED = 4.5;

onready var game	= get_node("/root/game");

onready var body	= get_node("body");
onready var raycast	= get_node("ray");

onready var pfb_fpsCam = load("res://prefabs/fpsCam.tscn");
onready var pfb_deathCam = load("res://prefabs/deathCam.tscn");
onready var pfb_gunDecal = load("res://prefabs/gunDecal.tscn");

var camera;
var hv = Vector3();
var jumping = false;

sync var yaw = 0.0;
sync var pos = Vector3();
sync var linear_velocity = Vector3();

slave var dir = Vector3();
slave var input = [0, 0];
slave var raydir = [Vector3(), Vector3()];

var playerAnimation;
var weaponAnimation;

var player_id = -1;
var player_name = "";
var player_health = 100.0;
var player_lastHit = 0.0;
var player_ani = "";
var player_curAni = "";
var player_nextSpawn = 0.0;
var player_nextClientDataSync = 0.0;

var wpn_ani = "";
var wpn_curAni = "";
var wpn_clip = 30;
var wpn_maxclip = wpn_clip;
var wpn_ammo = 360;
var wpn_damage = [12.0, 18.0];
var wpn_firing = false;
var wpn_reloading = false;
var wpn_nextIdle = 0.0;
var wpn_nextShoot = 0.0;

func _ready():
	player_health = 100.0;
	
	if (get_tree().is_network_server()):
		raycast.add_exception(self);
		
		game.gui.ui_scoreBoard.rpc("add_item", player_id, player_name, 0, 0);
	
	if (!is_network_master()):
		game.gui.ui_minimap.add_object(self);
	
	playerAnimation = body.get_node("models").find_node("AnimationPlayer");
	
	rpc("player_spawned");
	
	set_process(true);
	set_fixed_process(true);

func attachFPSCam():
	if (camera != null):
		camera.queue_free();
		camera = null;
	
	camera = pfb_fpsCam.instance();
	camera.set_name("camera");
	camera.set_translation(get_node("camPos").get_translation());
	add_child(camera);
	
	weaponAnimation	= camera.weapon.find_node("AnimationPlayer");
	
	body.hide();

func attachDeathCam(target = null):
	if (camera != null):
		camera.queue_free();
		camera = null;
	
	camera = pfb_deathCam.instance();
	camera.set_name("camera");
	camera.target = target;
	camera.startPos = get_node("camPos").get_translation();
	add_child(camera);
	
	body.show();

func _exit_tree():
	if (get_tree().is_network_server()):
		game.gui.ui_scoreBoard.rpc("remove_item", player_id);
	
	if (!is_network_master()):
		game.gui.ui_minimap.remove_object(self);

func _process(delta):
	if (get_tree().is_network_server()):
		respawn();
		
		if (game.time > player_nextClientDataSync):
			var cl_data = [
				player_health,
				wpn_clip,
				wpn_ammo
			];
			rpc_unreliable("client_data", cl_data);
			player_nextClientDataSync = game.time+1/30.0;

func can_spawn():
	return !is_alive() && game.time > player_nextSpawn;

func respawn():
	if (!can_spawn()):
		return;
	
	player_health = 100.0;
	set_translation(Vector3(0,1,0));
	
	rpc("player_spawned");

func _fixed_process(delta):
	if (is_network_master() && is_alive()):
		var cam_trans = camera.camera.get_global_transform();
		raydir = [
			cam_trans.origin,
			(cam_trans.xform(Vector3(0, 0, -1))-cam_trans.origin).normalized()
		];
		rset_unreliable("raydir", raydir);
		
		game.gui.ui_minimap.pos = get_global_transform().origin;
		game.gui.ui_minimap.rot = yaw;
		
		input[0] = Input.is_action_pressed("shoot");
		input[1] = Input.is_action_pressed("reload");
		
		rset_unreliable("input", input);
		rset_unreliable("yaw", camera.yaw);
	
	if (get_tree().is_network_server()):
		if (is_alive()):
			if (is_moving()):
				set_playerAnimation("run");
			else:
				set_playerAnimation("idle");
			
			wpn_idle();
			wpn_shoot();
			wpn_reload();
		
		else:
			set_playerAnimation("die");
		
		if (player_curAni != player_ani):
			rpc("set_playerAnimation", player_ani, true);
			player_curAni = player_ani;
	
	if (is_alive() && body != null):
		body.set_rotation(Vector3(0, deg2rad(yaw), 0));
	
	if (get_tree().is_network_server()):
		rset_unreliable("pos", get_translation());
	else:
		var delta_pos = pos-get_translation();
		if (delta_pos.length() <= 1.0 || delta_pos.length() > 10.0):
			set_translation(pos);
		else:
			set_translation(get_translation().linear_interpolate(pos, 10*delta));

func _integrate_forces(state):
	var delta = state.get_step();
	var lv = get_linear_velocity();
	
	if (is_network_master() && is_alive()):
		var basis = camera.camera.get_global_transform().basis;
		dir = Vector3();
		
		if (Input.is_key_pressed(KEY_W)):
			dir -= basis[2];
		if (Input.is_key_pressed(KEY_S)):
			dir += basis[2];
		if (Input.is_key_pressed(KEY_A)):
			dir -= basis[0];
		if (Input.is_key_pressed(KEY_D)):
			dir += basis[0];
		
		dir.y = 0;
		dir = dir.normalized();
		
		rset_unreliable("dir", dir);
		
		if (Input.is_action_just_pressed("jump")):
			rpc("jump");
	
	if (get_tree().is_network_server()):
		if (typeof(dir) != TYPE_VECTOR3):
			dir = Vector3();
		dir = dir.normalized();
		dir *= SPEED;
		
		if (!is_alive()):
			dir *= 0.0;
		elif (!raycast.is_colliding() || game.time < player_lastHit):
			dir *= 0.5;
		elif (is_firing()):
			dir *= 0.8;
		
		hv = hv.linear_interpolate(dir, 10*delta);
		
		lv.x = hv.x;
		lv.z = hv.z;
		
		if (jumping && is_alive()):
			if (raycast.is_colliding()):
				lv.y = 6.0;
			jumping = false;
		
		set_linear_velocity(lv);
		rset_unreliable("linear_velocity", lv);

func is_alive():
	return player_health > 0.0;

func is_moving():
	return is_alive() && linear_velocity.length() > 0.5;

func is_firing():
	return is_alive() && wpn_firing;

sync func set_playerAnimation(ani = player_ani, force = false):
	player_ani = ani;
	
	if (playerAnimation.get_current_animation() != ani || force):
		playerAnimation.play(ani);

master func set_wpnAnimation(ani = wpn_ani, force = false):
	wpn_ani = ani;
	
	if (is_network_master() && is_alive()):
		if (force):
			weaponAnimation.play(ani);

func wpn_idle():
	if (game.time < wpn_nextIdle):
		return;
	
	if (wpn_reloading):
		wpn_ammo -= wpn_maxclip-wpn_clip;
		wpn_clip = wpn_maxclip;
		wpn_reloading = false;
	
	set_wpnAnimation("idle");
	
	wpn_nextIdle = game.time+0.1;
	wpn_firing = false;
	
	if (is_alive() && wpn_curAni != wpn_ani):
		rpc("set_wpnAnimation", wpn_ani, true);
		wpn_curAni = wpn_ani;

func wpn_shoot():
	if (game.time < wpn_nextShoot || wpn_reloading || !input[0]):
		return;
	
	if (!wpn_clip):
		return;
	
	wpn_clip -= 1;
	
	var ray_src = raydir[0];
	var ray_len = 50.0;
	var ray_spread = Vector3(rand_range(-0.04, 0.04), rand_range(-0.04, 0.04), 0.0);
	var ray_target = raydir[0]+((raydir[1]+ray_spread)*ray_len);
	var result = get_world().get_direct_space_state().intersect_ray(ray_src, ray_target, [self]);
			
	if (!result.empty() && result.collider != null):
		if (result.collider extends get_script()):
			result.collider.rpc("apply_damage", player_id, rand_range(wpn_damage[0], wpn_damage[1]));
		if (result.collider extends StaticBody):
			rpc_unreliable("gun_decal", result.position, result.normal);
	
	rpc_unreliable("set_wpnAnimation", "shoot", true);
	rpc_unreliable("apply_clientfx", Vector2(rand_range(-2.0, 2.0), rand_range(-0.5, 2.0))*0.35);
	
	wpn_nextIdle = game.time+0.3;
	wpn_nextShoot = game.time+1/18.0;
	wpn_firing = true;

func wpn_reload():
	if (game.time < wpn_nextShoot || wpn_clip >= wpn_maxclip || !input[1]):
		return;
	if (wpn_firing || wpn_reloading):
		return;
	
	rpc("set_wpnAnimation", "reload", true);
	
	wpn_nextIdle = game.time+2.0;
	wpn_nextShoot = wpn_nextIdle;
	wpn_firing = false;
	wpn_reloading = true;

sync func jump():
	if (!get_tree().is_network_server()):
		return;
	jumping = true;

master func apply_clientfx(recoil):
	if (!is_network_master()):
		return;
	
	camera.give_recoil(recoil);
	game.gui.ui_crosshair.apply_firing();

master func client_data(cl_data):
	if (!is_network_master()):
		return;
	
	player_health = cl_data[0];
	wpn_clip = cl_data[1];
	wpn_ammo = cl_data[2];
	
	game.gui.ui_lblHealth.set_text(str(int(player_health)).pad_zeros(3));
	game.gui.ui_lblAmmo.set_text(str(int(wpn_clip)).pad_zeros(3) + "/" + str(int(wpn_ammo)).pad_zeros(3));

sync func apply_damage(attacker, dmg):
	if (get_tree().is_network_server()):
		if (is_alive()):
			player_health = max(player_health-dmg, 0.0);
			player_lastHit = game.time+1.0;
			
			if (!is_alive()):
				rpc("player_killed", attacker);
	
	if (is_network_master()):
		if (is_alive() && dmg > 0.0):
			game.gui.fx_bloodOverlay();

sync func gun_decal(pos, normal):
	var inst = pfb_gunDecal.instance();
	inst.look_at_from_pos(pos, pos+normal, Vector3(1,1,1));
	game.env.add_child(inst);

sync func set_targetable():
	set_mode(MODE_CHARACTER);
	
	for i in range(0, get_shape_count()):
		set_shape_as_trigger(i, false);

sync func set_untargetable():
	set_mode(MODE_STATIC);
	
	for i in range(0, get_shape_count()):
		set_shape_as_trigger(i, true);

sync func player_killed(killer):
	if (get_tree().is_network_server()):
		player_nextSpawn = game.time+3.0;
		rpc("drawSpawnBar", 3.0);
		
		game.gui.ui_scoreBoard.increase_kill(killer, 1);
		game.gui.ui_scoreBoard.increase_death(player_id, 1);
		
		rpc("set_untargetable");
	
	if (is_network_master()):
		player_health = 0;
		attachDeathCam(game.playerByID(killer));

sync func player_spawned():
	if (get_tree().is_network_server()):
		rpc("set_targetable");
	
	if (is_network_master()):
		attachFPSCam();
		
		rpc("player_ready");

sync func player_ready():
	if (get_tree().is_network_server()):
		rpc("set_wpnAnimation", "reload", true);

sync func drawSpawnBar(time):
	if (!is_network_master()):
		return;
	
	game.gui.ui_spawnBar.draw_spawnBar(time);
