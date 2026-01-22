ffmpeg -i 龙腾九天_good.mov \
-filter_complex "
[0:v]format=rgba,split=2[rgb][a];
[a]alphaextract,format=yuv420p,scale=trunc(iw/2)*2:trunc(ih/2)*2[a_gray];
[rgb]format=yuv420p,scale=trunc(iw/2)*2:trunc(ih/2)*2[rgb_yuv];
[a_gray][rgb_yuv]hstack=inputs=2
" \
-c:v libx264 \
-pix_fmt yuv420p \
-profile:v high \
-level 4.2 \
-crf 14 \
-preset slow \
-movflags +faststart \
龙腾九天_good.mp4








Administrator
lygyun2009