extends Panel

@onready var main_menu := get_parent() as MainMenu;

func _ready():
	call_deferred("_ready_later");

func _ready_later():
	$VBox/ButtonRandom.pressed.connect(func():
		main_menu.song_list.choose_song_random();
	);
