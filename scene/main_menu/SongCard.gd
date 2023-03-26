extends Panel

var modulate_v_origin = 1;
var modulate_v_hover = 1.3;
var modulate_v_select = 1.5;
var modulate_v_target = modulate_v_origin;

@onready var width_origin := custom_minimum_size.x;
@onready var width_select_mul := 1.2;
@onready var width_target := width_origin;
var width_offset := 0.0;

var is_mouse_entered := false;
var pressed_pos;
var selected = false;

signal song_selected(index :int);

func _ready():
	
	mouse_entered.connect(func():
		is_mouse_entered = true;
		modulate_v_target = modulate_v_hover;
	);
	
	mouse_exited.connect(func():
		is_mouse_entered = false;
		unhover();
	);

func _process(_delta):
	if modulate.v != modulate_v_target:
		modulate.v = Global.stick_edge(lerpf(modulate.v, modulate_v_target, 0.1));
	if custom_minimum_size.x != width_target + width_offset:
		custom_minimum_size.x = Global.stick_edge(lerpf(custom_minimum_size.x, width_target + width_offset, 0.2));

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index > MOUSE_BUTTON_LEFT: return;
		if event.pressed:
			# 在当前card上按下了
			accept_event();
			if !selected:
				pressed_pos = event.global_position;
				print(pressed_pos);
		else:
		# 在当前card上松手了
			if !selected:
				var y_relate = event.global_position.y - pressed_pos.y;
				pressed_pos = null;
				# 松手后和点击位置距离小于5px时断定为“选中”
				if abs(y_relate) <= 5.0:
					select();
				else:
					unhover();
			else:
				var packed_scene_playground = load("res://scene/play_ground/play_ground.tscn") as PackedScene;
				var scene := packed_scene_playground.instantiate();
				get_tree().root.add_child(scene);
				get_tree().current_scene = scene;
				Global.freeze(Global.scene_MainMenu);
				Global.scene_MainMenu.visible = true;
				#get_tree().root.remove_child(Global.scene_MainMenu);

func _input(event):
	if event is InputEventMouseButton:
		if event.button_mask != MOUSE_BUTTON_LEFT: return;
		if selected && event.pressed && !get_global_rect().has_point(event.position):
			modulate_v_target = modulate_v_origin;
			width_target = width_origin;
			selected = false;

func select():
	selected = true;
	modulate_v_target = modulate_v_select;
	width_target = width_origin * width_select_mul;
	song_selected.emit(get_index());

func unhover():
	if !selected: modulate_v_target = modulate_v_origin;
