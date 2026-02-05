package com.example.my_alpha_player

object AlphaShader {
    // 顶点着色器：非常标准，不用改
    const val VERTEX_SHADER = """
        attribute vec4 aPosition;
        attribute vec4 aTexCoord;
        varying vec2 vTexCoord;
        void main() {
            gl_Position = aPosition;
            vTexCoord = aTexCoord.xy;
        }
    """

    // 片元着色器：核心逻辑在这里！
    // 你的视频是：[左边 Alpha] | [右边 Color]
    const val FRAGMENT_SHADER = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        varying vec2 vTexCoord;
        uniform samplerExternalOES sTexture; // Android 视频专用采样器

        void main() {
            // 1. 采样右半边 -> 彩色 (Color)
            // 原理：把当前 UV 的 x 坐标压缩一半，再向右平移 0.5
            // 假设 vTexCoord 已经是 0.0~0.5 (在 Renderer 里设置)，那么 +0.5 就到了右边
            vec2 colorUV = vTexCoord + vec2(0.5, 0.0);
            vec4 color = texture2D(sTexture, colorUV);

            // 2. 采样左半边 -> 透明度 (Alpha)
            // 假设 vTexCoord 是 0.0~0.5，直接取就是左边
            vec2 alphaUV = vTexCoord;
            float alpha = texture2D(sTexture, alphaUV).r; // 取红色通道做透明度

            // 3. 合成
            gl_FragColor = vec4(color.rgb, alpha);
        }
    """
}