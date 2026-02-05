### FZXT FLUTTER

- Download dependencies

`flutter pub get`

Run flutter app

`flutter run`


> 101.200.77.1
- administrator weileyouFZXT2017




ffmpeg -re -stream_loop -1 -i /Users/luna/Downloads/123.MOV \
-vcodec libx264 -acodec aac \[slow1.txt](../../../../Downloads/slow1.txt)
-f flv rtmp://101.200.77.1:1935/live/test



ffmpeg -re -stream_loop -1 -i /Users/luna/Downloads/S50929-20540624-1.mp4 \
-c:v libx264 -preset veryfast \
-b:v 1000k -maxrate 1000k -bufsize 2000k \
-s 1280x720 \
-c:a aac -b:a 128k \
-f flv rtmp://101.200.77.1:1935/live/test



curl -o NUL -s -w "dns:%{time_namelookup} connect:%{time_connect} ssl:%{time_appconnect} start:%{time_starttransfer} total:%{time_total} code:%{http_code}\n" "http://127.0.0.1:80/i/getUserInfo.action?isHiddenLoading=YES&token=f3dff6d452712943630065b1c0eda687&ticket=BC34A09F627467F09177DA2B9719909CCE6FF84B0568A240B2014C1B7DE4F5DB"
Request Method
GET"


curl -o NUL -s -w "dns:%{time_namelookup} connect:%{time_connect} ssl:%{time_appconnect} start:%{time_starttransfer} total:%{time_total} code:%{http_code}\n" "http://101.200.77.1:80/i/getUserInfo.action?isHiddenLoading=YES&token=f3dff6d452712943630065b1c0eda687&ticket=BC34A09F627467F09177DA2B9719909CCE6FF84B0568A240B2014C1B7DE4F5DB"





curl -o NUL -s -w "8358  start:%{time_starttransfer} total:%{time_total} code:%{http_code}\n" "http://127.0.0.1:8888/active/top30"

for /L %i in (1,1,10) do @curl -o NUL -s -w "8358 #%i start:%{time_starttransfer} total:%{time_total} code:%{http_code}\n" "http://127.0.0.1:8888/active/top30"

for /L %i in (1,1,10) do @curl -o NUL -s -w "180  #%i start:%{time_starttransfer} total:%{time_total} code:%{http_code}\n" "http://127.0.0.1:180/i/getUserInfo.action?isHiddenLoading=YES&token=f3dff6d452712943630065b1c0eda687&ticket=BC34A09F627467F09177DA2B9719909CCE6FF84B0568A240B2014C1B7DE4F5DB"


set "API=http://127.0.0.1:180/i/getUserInfo.action?isHiddenLoading=YES&token=f3dff6d452712943630065b1c0eda687&ticket=BC34A09F627467F09177DA2B9719909CCE6FF84B0568A240B2014C1B7DE4F5DB"
for /L %i in (1,1,9999) do @curl -o NUL -s -H "Host: s0.efzxt.com" -w "REQ #%i start:%{time_starttransfer} total:%{time_total} code:%{http_code}\n" "%API%"

curl -v --noproxy "*" -o NUL -w "dns:%{time_namelookup} connect:%{time_connect} ssl:%{time_appconnect} start:%{time_starttransfer} total:%{time_total} code:%{http_code} err:%{errormsg}\n" -H "Host: s0.efzxt.com" "http://127.0.0.1:80/i/getUserInfo.action?isHiddenLoading=YES&token=f3dff6d452712943630065b1c0eda687&ticket=BC34A09F627467F09177DA2B9719909CCE6FF84B0568A240B2014C1B7DE4F5DB"