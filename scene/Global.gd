extends Node

## 界面Strech大小
var stretch_scale := 1.0;
## 与游戏窗口原比例关于宽度的比值
var window_wide_ratio := 1.0;
## 是否为全屏
var full_screen := false;

## 主界面
var mainMenu :MainMenu;
## 设置界面
var setting :Control;
## Debug界面
var debugInfo :Control;

## 上次旋转屏幕方向的游戏时间
var last_auto_rotate := 0.0;
## 自动旋转冷却时间
var auto_rotate_cd := 1.0;

## 当前使用的手柄
var gamepad_id := -1;
## 手柄个数
var gamepad_count := 0;

## 文件存储位置（有可能是user://）
var storage_path := "user://";
## Android用户文件根目录
var android_storage_path := "/storage/emulated/0/";

## 设置已加载
signal data_loaded_setting;
var data_has_loaded_setting := false;


func _ready():
	
	# 请求安卓权限
	OS.request_permissions();
	
	var model_name = OS.get_name();
	match model_name:
		"Android":
			if FileAccess.file_exists("user://storage_location"): return;
			var storage_location_file := FileAccess.open("user://storage_location", FileAccess.READ_WRITE);
			if storage_location_file != null && FileAccess.get_open_error() == OK:
				storage_location_file.store_string(get_android_path("dicolo!"));
				storage_location_file.flush();
				storage_location_file.close();
	
	if FileAccess.file_exists("user://storage_location"):
		print("reading user://storage_location...")
		var storage_location_file := FileAccess.open("user://storage_location", FileAccess.READ);
		if storage_location_file == null:
			var err := FileAccess.get_open_error();
			pop_text(
				"Unable to read user://storage_location,
				using default user:// location!
				
				error: " + error_string(err))
		var storage_location := storage_location_file.get_as_text();
		print("storage_location: ", storage_location);
		print("↑ checking useability");
		if (!DirAccess.dir_exists_absolute(storage_location)):
			print("↑ path not exist, creating...")
			var err := DirAccess.make_dir_recursive_absolute(storage_location);
			if err != OK:
				pop_text("Unable to create user folder at "+storage_location+"
				error: "+error_string(err));
		var storage_dir := DirAccess.open(storage_location);
		if storage_dir == null:
			var err := DirAccess.get_open_error();
			pop_text(
				"Unable to read storage_location,
				using default user:// location!
				
				error: " + error_string(err))
		else:
			print("ok! use it.");
			storage_path = storage_location if storage_location.ends_with('/') else storage_location+'/';
	
	get_tree().root.size_changed.connect(func():
		var now = get_tree().root.size;
		var origin_ratio :float = ProjectSettings.get_setting("display/window/size/width", 1152.0) / ProjectSettings.get_setting("display/window/size/height", 648.0);
		window_wide_ratio = (float(now.x) / now.y) / origin_ratio;
	);
	
	# 搞到检查数据文件夹
	print("Current res:// path: ", ProjectSettings.globalize_path("res://"));
	print("Current user:// path: ", ProjectSettings.globalize_path("user://"));
	print("Current storage path: ", storage_path);
	
	_ready_later.call_deferred();

## 获取存储文件的地方，sub_path为子文件位置
func get_storage_path(sub_path: String = "") -> String:
	return storage_path + sub_path;

func open_storage_path(sub_path: String = "") -> DirAccess:
	return DirAccess.open(get_storage_path(sub_path));

func open_storage_file(sub_file_path: String, flags: FileAccess.ModeFlags) -> FileAccess:
	return FileAccess.open(get_storage_path(sub_file_path), flags);

func get_android_path(sub_path: String = "") -> String:
	return android_storage_path + sub_path;

func _ready_later():
	
	print("load scene DebugInfo");
	var packed_debugInfo := preload("res://scene/test/DebugInfo.tscn") as PackedScene;
	debugInfo = packed_debugInfo.instantiate();
	debugInfo.z_index = 12;
	get_tree().root.add_child(debugInfo);
	debugInfo.mouse_filter = Control.MouseFilter.MOUSE_FILTER_IGNORE;
	
	print("load scene Setting");
	var packed_setting := preload("res://scene/setting/Setting.tscn") as PackedScene;
	setting = packed_setting.instantiate();
	setting.visible = false;
	setting.z_index = 11;
	get_tree().root.add_child(setting);
	setting.mouse_filter = Control.MouseFilter.MOUSE_FILTER_IGNORE;
	
	Notifier.container.z_index = 13;

func _notification(what):
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			print("[notification] BACK (Android)");
			var esc_event := InputEventAction.new();
			esc_event.action = "esc";
			esc_event.pressed = true;
			Input.parse_input_event(esc_event);

func _process(_delta):
	
	var elapsed_time := get_elapsed_time();
	
	# 自动旋转
	if elapsed_time > last_auto_rotate + auto_rotate_cd && Input.get_accelerometer().y > 5: # 降低灵敏，只有转过头才会旋转方向
		last_auto_rotate = elapsed_time;
		if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_LANDSCAPE:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_REVERSE_LANDSCAPE);
		else: DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE);

## int 转换为二进制形式的字符串
func int2bin(value: int, min_digit: int = 1) -> String:
	if value <= 0: return "0".repeat(min_digit);
	var out := "";
	var digit := 0;
	while value > 0:
		out = ("1" if value & 1 else "0") + out;
		value >>= 1;
		digit += 1;
	if digit < min_digit:
		out = "0".repeat(min_digit - digit) + out;
	return out;


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
	return Time.get_ticks_msec()/1000.0;

## 弹出一个点击后关闭的窗口
func pop_text(text:String, exit_when_close:bool = false) -> AcceptDialog:
	var dialog := AcceptDialog.new();
	dialog.dialog_text = text;
	if exit_when_close:
		dialog.canceled.connect(func(): get_tree().quit());
		dialog.confirmed.connect(func(): get_tree().quit());
	add_child(dialog);
	dialog.popup_centered();
	return dialog;

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

## 获取文件名
func get_file_name(path: String) -> String:
	return path.substr(path.rfind("/")+1);

## 移动某个文件(或文件夹下所有的文件)到to_path文件夹
func move_file(from_path: String, to_path: String, 
	exclude_dirs: Array[String]=[], exclude_files: Array[String]=[], relative_from_path:=""
) -> Error:
	var err: Error;
	if DirAccess.dir_exists_absolute(from_path):
		if !DirAccess.dir_exists_absolute(to_path):
			err = DirAccess.make_dir_recursive_absolute(to_path);
			if err != OK: return err;
		var dir_from := DirAccess.open(from_path);
		err = DirAccess.get_open_error();
		if err != OK: return err;
		if !from_path.ends_with("/"): from_path += "/";
		if !to_path.ends_with("/"): to_path += "/";
		DirAccess.make_dir_absolute(to_path);
		for sub_dir_name in DirAccess.get_directories_at(from_path):
			if exclude_dirs.has(relative_from_path+sub_dir_name): continue;
			move_file(from_path+sub_dir_name, to_path+sub_dir_name,
				exclude_dirs, exclude_files, relative_from_path+sub_dir_name+"/");
		for sub_file_name in DirAccess.get_files_at(from_path):
			if exclude_files.has(relative_from_path+sub_file_name): continue;
			move_file(from_path+sub_file_name, to_path+sub_file_name,
				exclude_dirs, exclude_files, relative_from_path+sub_file_name);
		DirAccess.remove_absolute(from_path);
	elif FileAccess.file_exists(from_path):
		var to_parent_dir = to_path.get_base_dir();
		if !DirAccess.dir_exists_absolute(to_parent_dir):
			err = DirAccess.make_dir_recursive_absolute(to_parent_dir);
			if err != OK: return err;
		if exclude_files.has(relative_from_path+Global.get_file_name(from_path)):
			return OK;
		DirAccess.copy_absolute(from_path, to_path, 744);
		DirAccess.remove_absolute(from_path);
	return OK;

## 播放声音
func play_sound(
		stream: AudioStream, volume: float = 0, pitch: float = 1, bus: String = "Master"
	) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new();
	add_child(player);
	player.stream = stream;
	player.volume_db = volume
	player.pitch_scale = pitch;
	player.bus = bus;
	player.finished.connect(func(): player.queue_free());
	player.play();
	return player;

## 获取一个FileDialog
## 请注意自行add_child()添加到场景树，pop_centered()显示窗口，处理选择/关闭信号
func get_file_dialog(
		file_mode: FileDialog.FileMode,
		access: FileDialog.Access,
		root_path: String = "",
		filters:= PackedStringArray(),
		window_size: Vector2i = Vector2i(1024, 512),
	) -> FileDialog:
	var fileDialog := FileDialog.new();
	if (OS.get_name() == "Android"): fileDialog.root_subfolder = Global.get_android_path(root_path);
	else: fileDialog.root_subfolder = root_path;
	fileDialog.file_mode = file_mode;
	fileDialog.access = access;
	fileDialog.filters = filters;
	fileDialog.size = window_size;
	fileDialog.canceled.connect(func(): fileDialog.queue_free());
	return fileDialog;
