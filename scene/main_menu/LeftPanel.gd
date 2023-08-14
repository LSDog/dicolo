extends Control


@onready var labelReadme :RichTextLabel = $Readme/Label;
@onready var labeScore :Label = $Score/Score;
@onready var labelCount :Label = $Score/Count;
@onready var buttonSetting := $VBoxButton/ButtonSetting;
@onready var buttonShop := $VBoxButton/ButtonShop;

func _ready():
	buttonSetting.mouse_entered.connect(play_hover_sound);
	buttonSetting.pressed.connect(func():
		play_click_sound();
		var setting := Global.setting;
		if !setting.visible:
			setting.anim_show();
		else:
			setting.anim_hide();
	);
	buttonShop.mouse_entered.connect(play_hover_sound);
	buttonShop.pressed.connect(func():
		play_click_sound();
		Notifier.notif_popup("Comming soon!", Notifier.COLOR_BLUE);
	);


func set_readme(text: String):
	labelReadme.text = text;
	labelReadme.scroll_to_line(0);
	labelReadme.get_v_scroll_bar().value = 0.0;

func set_score(score: int):
	labeScore.text = "%07d" % score;

func set_count(acc: float, combo: int):
	labelCount.text = "%.2f A\n%d C" % [acc*100.0, combo];

func play_hover_sound():
	Global.play_sound(preload("res://audio/ui/click_hat.wav"), -10, 1, "Effect");

func play_click_sound():
	Global.play_sound(preload("res://audio/ui/click_glass.wav"), -10, 1, "Effect");
