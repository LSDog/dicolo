extends Node

## 界面Strech大小
var stretch_scale = 1.0;
## 与游戏窗口原比例关于宽度的比值
var window_wide_ratio = 1.0;
## 是否为全屏
var full_screen = false;

## 主界面
var scene_MainMenu :MainMenu;
## 设置界面
var scene_Setting :Control;
## Debug界面
var scene_DebugInfo :Control;

## 上次旋转屏幕方向的游戏时间
var last_auto_rotate := 0.0;
## 自动旋转冷却时间
var auto_rotate_cd := 1;

## 当前使用的手柄
var gamepad_id = -1;
## 手柄个数
var gamepad_count = 0;

## 设置已加载
signal data_loaded_setting;
var data_has_loaded_setting: bool;

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
	
	_ready_later.call_deferred();

func _ready_later():
	var packed_scene_Setting := preload("res://scene/setting/Setting.tscn") as PackedScene;
	scene_Setting = packed_scene_Setting.instantiate();
	scene_Setting.visible = false;
	scene_Setting.z_index = 11;
	get_tree().root.add_child(scene_Setting);
	scene_Setting.mouse_filter = Control.MouseFilter.MOUSE_FILTER_IGNORE;
	
	var packed_scene_DebugInfo := preload("res://scene/test/DebugInfo.tscn") as PackedScene;
	scene_DebugInfo = packed_scene_DebugInfo.instantiate();
	scene_DebugInfo.z_index = 12;
	get_tree().root.add_child(scene_DebugInfo);
	scene_DebugInfo.mouse_filter = Control.MouseFilter.MOUSE_FILTER_IGNORE;
	
	Notifier.container.z_index = 13;

func _notification(what):
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			print("[notification] BACK (Android)");
			var esc_event = InputEventAction.new();
			esc_event.action = "esc";
			esc_event.pressed = true;
			Input.parse_input_event(esc_event);

func _process(_delta):
	
	var elapsed_time = get_elapsed_time();
	
	# 自动旋转
	if elapsed_time - last_auto_rotate > auto_rotate_cd && Input.get_accelerometer().y > 5: # 降低灵敏，只有转过头才会旋转方向
		last_auto_rotate = elapsed_time;
		if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_LANDSCAPE:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_REVERSE_LANDSCAPE);
		else: DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE);

## 获取左摇杆Vec
func get_joy_left() -> Vector2:
	if gamepad_id == -1: return Vector2.ZERO;
	return Vector2(
		Input.get_joy_axis(gamepad_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(gamepad_id, JOY_AXIS_LEFT_Y))

## 获取右侧摇杆Vec
func get_joy_right() -> Vector2:
	if gamepad_id == -1: return Vector2.ZERO;
	return Vector2(
		Input.get_joy_axis(gamepad_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(gamepad_id, JOY_AXIS_RIGHT_Y))

## 获取当前运行的时间 秒
func get_elapsed_time() -> float:
	return Time.get_unix_time_from_system() - Time.get_ticks_msec()/1000.0;

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

## 播放声音
func play_sound(stream: AudioStream, volume: float = 0, pitch: float = 1, bus: String = "Master"):	
	var player = AudioStreamPlayer.new();
	add_child(player);
	player.stream = stream;
	player.volume_db = volume
	player.pitch_scale = pitch;
	player.bus = bus;
	player.finished.connect(func(): player.queue_free());
	player.play();
