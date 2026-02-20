ffmpeg -i 御龙游侠底座.mov -vf "fps=8,scale=86:-1:flags=neighbor,palettegen=max_colors=64" base_dragon.png

ffmpeg -i 御龙游侠底座.mov -i base_dragon.png -lavfi "fps=8,scale=86:-1:flags=neighbor[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5" base_dragon.gif




ffmpeg -i 御龙游侠底座.mov -vf "fps=10,scale=480:-1:flags=lanczos,palettegen" base_dragon.png

ffmpeg -i 御龙游侠底座.mov -i base_dragon.png -lavfi "fps=10,scale=480:-1:flags=lanczos[x];[x][1:v]paletteuse" base_dragon.gif

