@icon("res://visual/texture/ct.svg")
class_name Ct
extends Sprite2D

var trail :Line2D = null;
var curve :Curve2D = Curve2D.new();

var prev_position :Vector2;
var velocity :Vector2 = Vector2.ZERO;

# track中的相关变量 大部分由Playground负责计算
var pos :Vector2;
var distance :float;
var degree :float;
var velocity_degree :float;

func _ready():
	trail = $Trail;
	$Trail.name = name + "_" + $Trail.name;
	# 把轨道放外面去，本体的下方
	remove_child(trail);
	get_parent().add_child.call_deferred(trail);
	get_parent().move_child.call_deferred(trail, get_index());

func _process(_delta):
	
	# 处理轨迹
	if trail == null: return;
	var point_count = trail.get_point_count();
	if point_count > 10:
		trail.remove_point(0);
	trail.add_point(position)
	
	# 计算速度
	velocity = position - prev_position;
	prev_position = position;
