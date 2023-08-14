@tool
extends Node

## 存储/加载 json 格式数据的地方

## 数据路径
var data_path := Global.storage_path;

var data_setting :DataSetting;
var data_setting_path := "setting.tres";
signal data_setting_loaded;
var data_setting_has_loaded :bool = false;
func get_data_setting() -> DataSetting: return data_setting;
func save_data_setting(): save_res_data(data_setting, data_setting_path);

var data_player :DataPlayer;
var data_player_path := "player.tres";
signal data_player_loaded;
var data_player_has_loaded :bool = false;
func get_data_player() -> DataPlayer: return data_player;
func save_data_player(): save_res_data(data_player, data_player_path);

var all_data_has_loaded := false;
signal all_data_loaded;

func _ready():
	print("DataManager.gd enabled.");
	data_path = Global.storage_path;
	if data_exist(data_setting_path):
		data_setting = load_res_data(data_setting_path);
		data_setting_loaded.emit();
		data_setting_has_loaded = true;
	else:
		data_setting = DataSetting.new();
		save_data_setting();
	
	if data_exist(data_player_path):
		data_player = load_res_data(data_player_path);
		data_player_loaded.emit();
		data_player_has_loaded = true;
	else:
		data_player = DataPlayer.new();
		save_data_player();
	
	print("all the data has loaded.");
	all_data_has_loaded = true;
	all_data_loaded.emit();

## 检查数据文件是否存在于data_path之下
func data_exist(path: String) -> bool:
	return FileAccess.file_exists(data_path + path);

## 保存json数据
func save_json_data(data: Dictionary, path: String) -> void:
	var file := FileAccess.open(data_path + path, FileAccess.WRITE);
	file.store_string(JSON.stringify(data, "\t"));
	file.flush();
	file.close();
	print("[DataManager] saved ", path);

## 加载json数据
func load_json_data(path: String) -> Dictionary:
	var file := FileAccess.open(data_path + path, FileAccess.READ_WRITE);
	var data = JSON.parse_string(file.get_as_text());
	file.flush();
	file.close();
	print("[DataManager] loaded ", path);
	return data;

## 保存res/tres/scn/tscn等Resource数据
func save_res_data(data: Resource, path: String) -> void:
	var error = ResourceSaver.save(data, data_path + path,
		ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES
	);
	print("[DataManager] save ", path, ": ", error_string(error));

## 加载res/tres/scn/tscn等Resource数据
func load_res_data(path: String) -> Resource:
	var data :Resource = load(data_path + path);
	print("[DataManager] loaded ", path);
	return data;
