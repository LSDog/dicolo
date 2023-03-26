extends Control

@onready var sprite :Sprite2D = $Control/Sprite;
@onready var sprite_shader :ShaderMaterial = sprite.material;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	$Control.rotation = sin(Global.elapsed_time*1.5)/20.0;
	sprite.skew = sin(Global.elapsed_time*1.5)/100;
	sprite_shader.set_shader_parameter("rim_light_pos", Vector2(0.25, 0.3 + sin(Global.elapsed_time*1.5)/2.0));
	sprite_shader.set_shader_parameter("diffuse_light_pos", Vector2(0, 0.15 + sin(Global.elapsed_time*1.5)/5.0));
