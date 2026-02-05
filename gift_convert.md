ffmpeg -i 都市游侠2.mov \
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
都市游侠.mp4



ffmpeg -i 龙腾九天_as_都市游侠_1080x1920.mov \
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
-crf 23 \
-preset slow \
-movflags +faststart \
龙腾九天222222.mp4

ffmpeg -i 都市游侠2.mov -vf "hue=h=270" -c:a copy 都市游侠3.mov



Administrator
lygyun2009


ffmpeg -i 龙腾九天_new.mov \
-filter_complex "
[0:v]format=rgba,split=3[orig][rgb][alpha];
[alpha]alphaextract,format=gray[alpha_gray];
[orig]format=yuv420p,scale=w=iw:h=ih:flags=spline[orig_yuv];
[alpha_gray]scale=w=iw:h=ih:flags=spline,format=yuv420p[alpha_scaled];
[orig_yuv][alpha_scaled]hstack=inputs=2[final]
" \
-map "[final]" \
-c:v libx264 \
-pix_fmt yuv420p \
-profile:v high \
-level 4.2 \
-crf 18 \  # 降低CRF值以提高质量
-preset slower \  # 使用更慢的预设以获得更好质量
-b:v 20M \  # 指定码率，尤其适合有alpha通道的视频
-tune animation \  # 如果是动画内容
-x264-params "keyint=60:min-keyint=30:no-scenecut" \
-movflags +faststart \
龙腾九天222222.mp4



