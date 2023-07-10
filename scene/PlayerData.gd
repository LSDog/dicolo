class_name PlayerData
extends Resource

@export_category("Information")
@export var name :String = "Player";
@export var avatar :Texture2D = preload("res://visual/partner/avatar_trans-1024x.png");
@export var exp :int = 0;
@export var level :int = 0;

@export_category("Status")
var first_play :bool = true;

@export_category("Statistics")
@export var total_note :int = 0;

func _init() -> void:
	pass

func _to_string() -> String:
	var compare_obj := Resource.new();
	var prop_list := [];
	for dic in get_property_list():
		var name :String = dic["name"];
		if compare_obj.get(name) == null:
			prop_list.append('%s: %s' % [name, get(name)]);
	return str(prop_list);
