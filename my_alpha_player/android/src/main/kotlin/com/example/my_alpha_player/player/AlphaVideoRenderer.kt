package com.example.my_alpha_player.player

import android.graphics.SurfaceTexture
import android.opengl.GLES11Ext
import android.opengl.GLES20
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

class AlphaVideoRenderer(
    private val onSurfaceReady: (SurfaceTexture) -> Unit,
    private val onFrameAvailable: () -> Unit,
    private val onFirstFrameRendered: () -> Unit
) : SurfaceTexture.OnFrameAvailableListener {

    private var programId: Int = 0
    private var textureId: Int = 0
    private var vertexBuffer: FloatBuffer
    private var textureBuffer: FloatBuffer
    private var surfaceTexture: SurfaceTexture? = null

    @Volatile var currentParams = FilterParams()
    private var drawCount = 0
    private var hasDrawnFirstFrame = false

    @Volatile var isClear: Boolean = true
        set(value) {
            field = value
            if (value) {
                // 如果被外部强制设为 Clear，重置计数器
                drawCount = 0
                hasDrawnFirstFrame = false
            }
        }

    // Shader Uniforms ... (保持不变)
    private var hHue = 0; private var hSat = 0; private var hVal = 0
    private var hShadow = 0; private var hGamma = 0; private var hInLow = 0
    private var hMix = 0; private var hOn = 0

    private val vertexData = floatArrayOf(-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f, 1.0f, 1.0f)
    private val textureData = floatArrayOf(0.0f, 1.0f, 0.5f, 1.0f, 0.0f, 0.0f, 0.5f, 0.0f)

    init {
        vertexBuffer = ByteBuffer.allocateDirect(vertexData.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().put(vertexData).position(0) as FloatBuffer
        textureBuffer = ByteBuffer.allocateDirect(textureData.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().put(textureData).position(0) as FloatBuffer
    }

    fun updateViewport(width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
    }

    fun onSurfaceCreated() {
        val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, AlphaShader.VERTEX_SHADER)
        val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, AlphaShader.FRAGMENT_SHADER)

        programId = GLES20.glCreateProgram().also {
            GLES20.glAttachShader(it, vertexShader)
            GLES20.glAttachShader(it, fragmentShader)
            GLES20.glLinkProgram(it)
        }

        hHue = GLES20.glGetUniformLocation(programId, "uHue")
        hSat = GLES20.glGetUniformLocation(programId, "uSat")
        hVal = GLES20.glGetUniformLocation(programId, "uVal")
        hShadow = GLES20.glGetUniformLocation(programId, "uShadow")
        hGamma = GLES20.glGetUniformLocation(programId, "uGamma")
        hInLow = GLES20.glGetUniformLocation(programId, "uInLow")
        hMix = GLES20.glGetUniformLocation(programId, "uMixOrigin")
        hOn = GLES20.glGetUniformLocation(programId, "uTintOn")

        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        // 关键：必须设置 GL_NEAREST 或 GL_LINEAR，否则可能黑屏
        GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        surfaceTexture = SurfaceTexture(textureId)
        surfaceTexture?.setOnFrameAvailableListener(this)
        onSurfaceReady(surfaceTexture!!)
    }

    override fun onFrameAvailable(surfaceTexture: SurfaceTexture?) {
        // 收到视频帧 -> 通知 AlphaTextureView 的 RenderThread 醒来
        onFrameAvailable.invoke()
    }

    fun drawFrame() {
        // 1. 如果不是 Clear 模式，说明在播放视频，必须更新纹理
        // 如果是 Clear 模式，不需要更新纹理（因为没有视频流，或者是旧的）
        try {
            surfaceTexture?.updateTexImage()
        } catch (e: Exception) {
            // 忽略更新失败
        }

        // 2. 清屏透明
        GLES20.glClearColor(0f, 0f, 0f, 0f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        // 3. 拦截
        if (isClear) return
        drawCount++
        // 4. 丢帧保护：现在 drawCount 代表真实的“视频第几帧”
        // 丢弃前 5 帧，确保不闪黑
        if (drawCount <= 5) return

        // 5. 绘制
        GLES20.glUseProgram(programId)
        val p = currentParams
        GLES20.glUniform1f(hHue, p.hue)
        GLES20.glUniform1f(hSat, p.sat)
        GLES20.glUniform1f(hVal, p.value)
        GLES20.glUniform1f(hShadow, p.shadow)
        GLES20.glUniform1f(hGamma, p.gamma)
        GLES20.glUniform1f(hInLow, p.inLow)
        GLES20.glUniform1f(hMix, p.mixOrigin)
        GLES20.glUniform1f(hOn, if (p.isOn) 1.0f else 0.0f)

        val aPos = GLES20.glGetAttribLocation(programId, "aPosition")
        GLES20.glEnableVertexAttribArray(aPos)
        GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 0, vertexBuffer)

        val aTex = GLES20.glGetAttribLocation(programId, "aTexCoord")
        GLES20.glEnableVertexAttribArray(aTex)
        GLES20.glVertexAttribPointer(aTex, 2, GLES20.GL_FLOAT, false, 0, textureBuffer)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(programId, "sTexture"), 0)

        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisable(GLES20.GL_BLEND)

        GLES20.glDisableVertexAttribArray(aPos)
        GLES20.glDisableVertexAttribArray(aTex)

        if (!hasDrawnFirstFrame) {
            hasDrawnFirstFrame = true
            onFirstFrameRendered()
        }
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        return GLES20.glCreateShader(type).also { shader ->
            GLES20.glShaderSource(shader, shaderCode)
            GLES20.glCompileShader(shader)
        }
    }
}