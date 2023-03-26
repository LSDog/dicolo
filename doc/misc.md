### TODO

- 整个二次元桌宠到游戏里。好处：提升辨识度，吸引二刺螈  

### Sizing

default develop size: 1152*648  
   1  2/3  1/2  1/3  0  
1152  768  576  384  0  
 648  432  324  216  0

(贝塞尔曲线(Curve2D)拟合圆)[https://www.cnblogs.com/ArthurQQ/articles/1730214.html]  
简单总结: 若在Path2d中使用4个点拟合圆，其控制柄长度应为半径的`4*(2**0.5-1)/3`=`0.55228475`倍  
误差在平均1/2000左右，但这种近似圆"半径"长度均大于等于正常圆  
所以平均误差可以乘倍数`0.551784` (每隔30度，圆上的点精确匹配)  


### videos

Convert videos to ogv:  
`ffmpeg -i input.mp4 -vf "scale=-1:720" -an -q:v 6 output.ogv`  
this is the command line using `ffmpeg` to convert `input.mp4` to no audio 720P ogv video.
- note that `-an` means no audio.
- note that `-q:v 6` is the video quality (from 1~10).

### Coding
给自己的类/方法添加说明:  
```
## 方法说明 (BBcode支持见下方链接)
func _init():
	...
```
https://docs.godotengine.org/zh_CN/stable/community/contributing/class_reference_writing_guidelines.html?highlight=Description#improve-formatting-with-bbcode-style-tags
