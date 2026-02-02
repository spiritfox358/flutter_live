### FZXT FLUTTER

- Download dependencies

`flutter pub get`

Run flutter app

`flutter run`


> 101.200.77.1
- administrator weileyouFZXT2017




ffmpeg -re -stream_loop -1 -i /Users/luna/Downloads/123.MOV \
-vcodec libx264 -acodec aac \
-f flv rtmp://101.200.77.1:1935/live/test



ffmpeg -re -stream_loop -1 -i /Users/luna/Downloads/S50929-20540624-1.mp4 \
-c:v libx264 -preset veryfast \
-b:v 1000k -maxrate 1000k -bufsize 2000k \
-s 1280x720 \
-c:a aac -b:a 128k \
-f flv rtmp://101.200.77.1:1935/live/test