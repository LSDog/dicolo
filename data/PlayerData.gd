class_name PlayerData
extends Resource

@export_category("Information")
@export var name :String = "Player";
@export var avatar_path :String = "res://visual/partner/avatar_trans-1024x.png";
var avatar :Texture2D = null;
@export var exp :int = 0;
@export var level :int = 0;

@export_category("Status")
var first_play :bool = true;

@export_category("Statistics")
@export var total_note :int = 0;

func set_avatar(path: String):
	if path == avatar_path: return;
	remove_storage_file(avatar_path);
	avatar_path = storage_file(path);
	avatar = get_avatar();

func remove_storage_file(path: String):
	var path_storage := "user://.storage/";
	if !path.begins_with(path_storage) || !DirAccess.dir_exists_absolute(path_storage):
		return;
	DirAccess.remove_absolute(path);

func storage_file(path: String) -> String:
	var path_storage := "user://.storage/";
	if !DirAccess.dir_exists_absolute(path_storage):
		DirAccess.make_dir_absolute(path_storage);
	var new_path = path_storage + Global.get_file_name(path);
	DirAccess.copy_absolute(path, new_path);
	return new_path;

func get_avatar() -> ImageTexture:
	if avatar == null:
		if avatar_path.begins_with("res://"):
			avatar = load(avatar_path)
		else:
			var image = Image.new();
			image.load(avatar_path);
			avatar = ImageTexture.create_from_image(image);
	return avatar;

func _to_string() -> String:
	var compare_obj := Resource.new();
	var prop_list := [];
	for dic in get_property_list():
		var name :String = dic["name"];
		if compare_obj.get(name) == null:
			prop_list.append('%s: %s' % [name, get(name)]);
	return str(prop_list);
