extends Control


@onready var label_Readme :RichTextLabel = $Readme/Label;
@onready var panel_Score :Panel = $Score;
@onready var label_Score :Label = $Score/Score;
@onready var label_Count :Label = $Score/Count;


func _ready():
	pass


func set_readme(text: String):
	label_Readme.text = text;
	label_Readme.scroll_to_line(0);
	label_Readme.get_v_scroll_bar().value = 0.0;

func set_score(score: int):
	label_Score.text = "%07d" % score;

func set_count(acc: float, combo: int):
	label_Count.text = "%.2f A\n%d C" % [acc*100.0, combo];
