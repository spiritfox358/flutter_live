ffmpeg -i 龙腾九天.mov \
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
龙腾九天3.mp4






ffmpeg -i 520光年之恋.webm \
-filter_complex "
[0:v]split=2[v1][v2];
[v1]format=gray,scale=trunc(iw/2)*2:trunc(ih/2)*2[mask_gray];
[v2]scale=trunc(iw/2)*2:trunc(ih/2)*2[color_original];
[mask_gray][color_original]hstack=inputs=2[v]
" \
-map "[v]" \
-map "0:a?" \
-c:v libx264 \
-pix_fmt yuv420p \
-profile:v high \
-level 4.2 \
-crf 23 \
-preset slow \
-movflags +faststart \
-c:a aac -b:a 192k \
520光年之恋_原色版.mp4