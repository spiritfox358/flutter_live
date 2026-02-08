ffmpeg -i 云中秘境.mov \
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
云中秘境.mp4



ffmpeg -i 钻石邮轮.mov \
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
钻石邮轮.mp4

ffprobe -v quiet -show_streams 云中秘境.webm

// voice
ffmpeg -c:v libvpx-vp9 -i 云中鲸.webm -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le -alpha_bits 16 云中鲸.mov

// mute
ffmpeg -c:v libvpx-vp9 -i 热气球.webm -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le -alpha_bits 16 -an 热气球.mov

ffmpeg -i 嘉年华.webm \
-c:v prores_ks \
-profile:v 4444 \
-pix_fmt yuva444p10le \
-c:a aac \
-b:a 320k \
嘉年华.mov

ffmpeg -i 云中秘境.webm \
-c:v prores_ks \
-profile:v 4444 \
-pix_fmt yuva444p10le \
-c:a aac \
-b:a 320k \
云中秘境2.mov

Administrator
lygyun2009



