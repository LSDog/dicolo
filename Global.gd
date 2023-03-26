extends Node

var start_time = 0.0; # 启动的时间
var elapsed_time = 0.0; # 自游戏开始经过的时间（秒）
var stretch_scale = 1.0;
var window_wide_ratio = 1.0; # 与游戏窗口原比例关于宽度的比值
var full_screen = false;
var scene_MainMenu :Control = null;

var last_auto_rotate := 0.0; # 上次旋转（游戏内时间）
var auto_rotate_cd := 1;

var joypad_id = -1;
#var joy_l := Vector2.ZERO;
#var joy_r := Vector2.ZERO;

func _ready():
	
	start_time = Time.get_unix_time_from_system();
	
	get_tree().root.size_changed.connect(func():
		var now = get_tree().root.size;
		var origin_ratio :float = ProjectSettings.get_setting("display/window/size/width", 1152.0) / ProjectSettings.get_setting("display/window/size/height", 648.0);
		window_wide_ratio = (float(now.x) / now.y) / origin_ratio;
	);
	
	# 初始化数据文件夹
	var dir_res := DirAccess.open("res://");
	print("Current res:// path: ", ProjectSettings.globalize_path(dir_res.get_current_dir()));
	#print(" --dics--\n  ", "\n  ".join(dir_res.get_directories()))
	#print(" --files--\n  ", "\n  ".join(dir_res.get_files()))
	
	print(" ");
	
	var dir_user := DirAccess.open("user://");
	print("Current user:// path: ", ProjectSettings.globalize_path(dir_user.get_current_dir()));
	#print(" --dics--\n  ", "\n  ".join(dir_user.get_directories()))
	#print(" --files--\n  ", "\n  ".join(dir_user.get_files()))
	
	#var data_dir_path = dir.get_current_dir()+"/.dicolo!";
	#print("Data path: " + data_dir_path);
	#if !DirAccess.dir_exists_absolute(data_dir_path):
	#	var error = DirAccess.make_dir_absolute(data_dir_path);
	#	if error != OK:
	#		printerr(error_string(error));
	#		pop_text_exit("ERROR! " + error_string(error));
	
	# 信号
	Input.joy_connection_changed.connect(func(device: int, connected: bool):
		if connected:
			joypad_id = device;
		else:
			update_joypad();
	);
	
	_ready_later.call_deferred();

func _ready_later():
	var packed_scene_settings = load("res://scene/settings/settings.tscn") as PackedScene;
	var scene_settings = packed_scene_settings.instantiate();
	get_tree().root.add_child(scene_settings);

func _notification(what):
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			print("[notification] BACK (Android)");
			var esc_event = InputEventAction.new()
			esc_event.action = "esc"
			esc_event.pressed = true
			Input.parse_input_event(esc_event);

func _process(_delta):
	stretch_scale = get_tree().root.get_content_scale_factor();
	elapsed_time = get_elapsed_time();

	# 自动旋转
	if elapsed_time - last_auto_rotate > auto_rotate_cd && Input.get_accelerometer().y > 5: # 降低灵敏，只有转过头才会旋转方向
		last_auto_rotate = elapsed_time;
		if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_LANDSCAPE:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_REVERSE_LANDSCAPE);
		else: DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE);

func _unhandled_input(event):
	if event.is_action_pressed("full_screen"):
		if full_screen:
			full_screen = false;
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);
		else:
			full_screen = true;
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);

## 更新摇杆连接
func update_joypad():
	joypad_id = -1;
	for i in Input.get_connected_joypads():
		joypad_id = i;
		break;

func get_joy_left() -> Vector2:
	if joypad_id == -1: return Vector2.ZERO;
	return Vector2(
		Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_Y))

func get_joy_right() -> Vector2:
	if joypad_id == -1: return Vector2.ZERO;
	return Vector2(
		Input.get_joy_axis(joypad_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(joypad_id, JOY_AXIS_RIGHT_Y))

## 获取当前运行的时间
func get_elapsed_time():
	return Time.get_unix_time_from_system() - start_time;

## 将浮点数贴合到dege（在value与edge距离小于等于threshold时返回edge，否则返回原value）
func stick_edge(value:float, edge:float = 0, threshold:float = 0.01) -> float:
	return edge if abs(value-edge) <= threshold else value;

## 弹出一个点击后关闭的窗口
func pop_text_exit(text:String):
	var dialog := AcceptDialog.new();
	dialog.dialog_text = text;
	dialog.canceled.connect(func(): get_tree().quit());
	dialog.confirmed.connect(func(): get_tree().quit());
	add_child(dialog);
	dialog.popup_centered();

func now_time() -> float:
	return Time.get_unix_time_from_system();

func freeze(node: Node):
	node.process_mode = PROCESS_MODE_DISABLED;

func unfreeze(node: Node):
	node.process_mode = PROCESS_MODE_INHERIT;
