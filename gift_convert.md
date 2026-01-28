ffmpeg -i 绮梦晶履.mov \
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
绮梦晶履.mp4





ffmpeg -i 龙腾九天2.mov \
-filter_complex "
[0:v]format=rgba,split=2[orig][for_alpha];
[for_alpha]alphaextract,format=yuv420p,scale=trunc(iw/2)*2:trunc(ih/2)*2[a_gray];
[orig]color=red:s=iw*ih:d=1:r=1[red_base];
[orig][red_base]scale2ref[rgb_scaled][red_resized];
[red_resized]format=yuv420p[rgb_red];
[a_gray][rgb_red]hstack=inputs=2
" \
-c:v libx264 \
-pix_fmt yuv420p \
-profile:v high \
-level 4.2 \
-crf 14 \
-preset slow \
-movflags +faststart \
龙腾九天2.mp4






Administrator
lygyun2009