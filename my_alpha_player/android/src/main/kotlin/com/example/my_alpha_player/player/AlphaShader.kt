package com.example.my_alpha_player.player

object AlphaShader {
    const val VERTEX_SHADER = """
        attribute vec4 aPosition;
        attribute vec4 aTexCoord;
        varying vec2 vTexCoord;
        void main() {
            gl_Position = aPosition;
            vTexCoord = aTexCoord.xy;
        }
    """

    const val FRAGMENT_SHADER = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        varying vec2 vTexCoord;
        uniform samplerExternalOES sTexture;
        
        uniform float uHue;
        uniform float uSat;
        uniform float uVal;
        uniform float uShadow;
        uniform float uGamma;
        uniform float uInLow;
        uniform float uMixOrigin;
        uniform float uTintOn;

        vec3 hsv2rgb(vec3 c) {
            vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
            return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
        }

        void main() {
            vec2 colorUV = vTexCoord + vec2(0.5, 0.0);
            vec4 originColor = texture2D(sTexture, colorUV);
            float alpha = texture2D(sTexture, vTexCoord).r;

            if (uTintOn > 0.5) {
                float luma = dot(originColor.rgb, vec3(0.299, 0.587, 0.114));
                vec3 targetColor = hsv2rgb(vec3(uHue, uSat, uVal));
                float t = smoothstep(uInLow, 1.0, luma);
                t = pow(t, uGamma);
                vec3 shadowColor = targetColor * uShadow;
                vec3 finalRGB = mix(shadowColor, targetColor, t);
                finalRGB = mix(finalRGB, originColor.rgb, uMixOrigin);
                gl_FragColor = vec4(finalRGB, alpha);
            } else {
                gl_FragColor = vec4(originColor.rgb, alpha);
            }
        }
    """
}