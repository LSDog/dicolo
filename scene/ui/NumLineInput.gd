@tool
class_name NumLineInput
extends Control

@onready var buttonSub: Button = $HBox/ButtonSub
@onready var lineEdit: LineEdit = $HBox/LineEdit
@onready var buttonAdd: Button = $HBox/ButtonAdd

@export var value :float = 0:
	set(v):
		if value == v: return;
		value = v;
		lineEdit.text = str(value);
@export var step :float = 1;

func _ready():
	lineEdit.text = "0";

func _process(delta: float):
	pass
