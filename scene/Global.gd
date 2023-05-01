extends Node

## 界面Strech大小
var stretch_scale = 1.0;
## 与游戏窗口原比例关于宽度的比值
var window_wide_ratio = 1.0;
## 是否为全屏
var full_screen = false;

## 主界面
var scene_MainMenu :Control = null;
## 设置界面
var scene_Settings :Control = null;
## Debug界面
var scene_DebugInfo :Control = null;

## 上次旋转屏幕方向的游戏时间
var last_auto_rotate := 0.0;
## 自动旋转冷却时间
var auto_rotate_cd := 1;

## 当前使用的joypad
var joypad_id = -1;
#var joy_l := Vector2.ZERO;
#var joy_r := Vector2.ZERO;

func _ready():
	
	get_tree().root.size_changed.connect(func():
		var now = get_tree().root.size;
		var origin_ratio :float = ProjectSettings.get_setting("display/window/size/width", 1152.0) / ProjectSettings.get_setting("display/window/size/height", 648.0);
		window_wide_ratio = (float(now.x) / now.y) / origin_ratio;
	);
	
	# 搞到数据文件夹
	var dir_res := DirAccess.open("res://");
	var dir_user := DirAccess.open("user://");
	
	print("Current res:// path: ", ProjectSettings.globalize_path(dir_res.get_current_dir()));
	print(" ");
	print("Current user:// path: ", ProjectSettings.globalize_path(dir_user.get_current_dir()));
	
	# 信号
	Input.joy_connection_changed.connect(func(device: int, connected: bool):
		if connected:
			joypad_id = device;
		else:
			update_joypad();
	);
	
	_ready_later.call_deferred();

func _ready_later():
	var packed_scene_Settings := load("res://scene/settings/settings.tscn") as PackedScene;
	scene_Settings = packed_scene_Settings.instantiate() as Control;
	scene_Settings.visible = false;
	scene_Settings.z_index = 11;
	get_tree().root.add_child(scene_Settings);
	scene_Settings.mouse_filter = Control.MouseFilter.MOUSE_FILTER_IGNORE;
	
	var packed_scene_DebugInfo := load("res://scene/test/debug_info.tscn") as PackedScene;
	scene_DebugInfo = packed_scene_DebugInfo.instantiate() as Control;
	scene_DebugInfo.z_index = 12;
	get_tree().root.add_child(scene_DebugInfo);
	scene_DebugInfo.mouse_filter = Control.MouseFilter.MOUSE_FILTER_IGNORE;

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
	
	var elapsed_time = get_elapsed_time();
	
	# 自动旋转
	if elapsed_time - last_auto_rotate > auto_rotate_cd && Input.get_accelerometer().y > 5: # 降低灵敏，只有转过头才会旋转方向
		last_auto_rotate = elapsed_time;
		if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_LANDSCAPE:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_REVERSE_LANDSCAPE);
		else: DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE);

## 更新摇杆连接
func update_joypad():
	joypad_id = -1;
	for i in Input.get_connected_joypads():
		joypad_id = i;
		break;

## 获取左摇杆Vec
func get_joy_left() -> Vector2:
	if joypad_id == -1: return Vector2.ZERO;
	return Vector2(
		Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_Y))

## 获取右侧摇杆Vec
func get_joy_right() -> Vector2:
	if joypad_id == -1: return Vector2.ZERO;
	return Vector2(
		Input.get_joy_axis(joypad_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(joypad_id, JOY_AXIS_RIGHT_Y))

## 获取当前运行的时间 秒
func get_elapsed_time() -> float:
	return Time.get_unix_time_from_system() - Time.get_ticks_msec()/1000.0;

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

## 获取当前系统时间 秒
func now_time() -> float:
	return Time.get_unix_time_from_system();

## 冻结某个node
func freeze(node: Node):
	node.process_mode = PROCESS_MODE_DISABLED;

## 还原冻结node
func unfreeze(node: Node):
	node.process_mode = PROCESS_MODE_INHERIT;

## 获取一个子文件夹
func get_sub_dir(parent_dir: DirAccess, sub_dir_name: String) -> DirAccess:
	return DirAccess.open(parent_dir.get_current_dir()+'/'+sub_dir_name);

## 获取一个文件夹内的文件
func get_sub_file(parent_dir: DirAccess, sub_file_name: String, flags: FileAccess.ModeFlags) -> FileAccess:
	return FileAccess.open(parent_dir.get_current_dir()+'/'+sub_file_name, flags);
