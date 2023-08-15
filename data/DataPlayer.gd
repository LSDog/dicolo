class_name DataPlayer
extends Resource

@export_category("Information")
@export var name :String = "Player";
## 头像存储的地方 注意是除非res://开头，否则使用Global.storage_location的相对位置
@export var avatar_path :String = "res://visual/partner/avatar_trans-1024x.png";
var avatar :Texture2D = null;
@export var experience :int = 0;
@export var level :int = 0;

@export_category("Status")
var first_play :bool = true;

@export_category("Statistics")
@export var total_note :int = 0;

func set_avatar(path: String):
	if path == avatar_path: return;
	remove_storage_file(avatar_path);
	storage_file(path);
	avatar_path = Global.get_file_name(path);
	avatar = null;

func get_avatar_path():
	if avatar_path.begins_with("res://"):
		return avatar_path;
	else:
		return Global.get_storage_path(".storage/")+avatar_path;

## 删除.storage里面的文件 path为相对 .storage 的位置
func remove_storage_file(path: String):
	if path.begins_with("res://"): return;
	var path_storage := Global.get_storage_path(".storage/");
	if !DirAccess.dir_exists_absolute(path_storage): return;
	DirAccess.remove_absolute(Global.get_storage_path(".storage/")+path);

## 复制文件到.storage中 path为指向文件的绝对路径，返回绝对路径
func storage_file(path: String) -> String:
	var path_storage := Global.get_storage_path(".storage/");
	if !DirAccess.dir_exists_absolute(path_storage):
		DirAccess.make_dir_absolute(path_storage);
	var new_path = path_storage + Global.get_file_name(path);
	DirAccess.copy_absolute(path, new_path);
	return new_path;

func get_avatar() -> ImageTexture:
	if avatar == null:
		avatar = ExternLoader.load_image(get_avatar_path());
	return avatar;

func _to_string() -> String:
	var compare_obj := Resource.new();
	var prop_list := [];
	for dic in get_property_list():
		var p_name :String = dic["name"];
		if compare_obj.get(p_name) == null:
			prop_list.append('%s: %s' % [p_name, get(p_name)]);
	return str(prop_list);
