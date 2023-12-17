class_name DataSetting
extends Resource

@export_category("Gameplay")
enum INPUT_MODE {NONE=-1,JOYSTICK,V_JOYSTICK,TOUCH}; ## 输入模式的枚举
@export var input_mode :INPUT_MODE = INPUT_MODE.JOYSTICK;

@export_category("Video")
@export var full_screen :bool = false;
enum FULL_SCREEN_MODE {FullScreen, BorderLess};
@export var full_screen_mode :FULL_SCREEN_MODE = FULL_SCREEN_MODE.FullScreen;
@export var fps :int = 60;
@export var v_sync :bool = true;
@export var scale :float = 1;

@export_category("Audio")
@export var volume_master :float = 0;
@export var volume_music :float = 0;
@export var volume_effect :float = 0;
@export var volume_voice :float = 0;
@export var audio_offset :float = 0;

@export_category("Misc")
@export var debug_info :bool = false;

@export_category("MusicPlayer")
@export var music_player_loop :bool = false;
