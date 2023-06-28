extends Node

var data_path := "user://"

enum DATA_TYPE {SETTING};
const DATA_INFO := {
	DATA_TYPE.SETTING: ["data_setting", "setting.json"]
}

var data_setting := {};


func save_data(data_type: DATA_TYPE):
	
	var info = DATA_INFO.get(data_type);
	var var_name :String = info[0];
	var data_file :String = info[1];
	var data :Dictionary = get(var_name);
	
	var file := FileAccess.open(data_path + data_file, FileAccess.WRITE);
	file.store_string(JSON.stringify(data, "\t"));
	file.flush();
	file.close();
	
	print("[DataManager] saved ", data_file);

func load_data(data_type: DATA_TYPE):
	
	var info = DATA_INFO.get(data_type);
	var var_name :String = info[0];
	var data_file :String = info[1];
	
	var file := FileAccess.open(data_path + data_file, FileAccess.READ_WRITE);
	var data_loaded = JSON.parse_string(file.get_as_text());
	if data_loaded != null: set(var_name, data_loaded);
	file.flush();
	file.close();
	
	print("[DataManager] loaded ", data_file);
