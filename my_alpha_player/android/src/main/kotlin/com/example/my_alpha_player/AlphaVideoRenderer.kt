package com.example.my_alpha_player

import android.graphics.SurfaceTexture
import android.opengl.GLES11Ext
import android.opengl.GLES20
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

class AlphaVideoRenderer(private val onSurfaceReady: (SurfaceTexture) -> Unit) {

    private var programId: Int = 0
    private var textureId: Int = 0
    private var vertexBuffer: FloatBuffer
    private var textureBuffer: FloatBuffer

    // 强引用
    private var surfaceTexture: SurfaceTexture? = null
    // 防鬼影
    @Volatile
    private var isClear: Boolean = true

    private val vertexData = floatArrayOf(
        -1.0f, -1.0f,  1.0f, -1.0f,
        -1.0f,  1.0f,  1.0f,  1.0f
    )

    // ✅ 正常版本的坐标：底部(V=1.0) -> 顶部(V=0.0)
    // 确保画面是正的
    private val textureData = floatArrayOf(
        0.0f, 1.0f, 0.5f, 1.0f,
        0.0f, 0.0f, 0.5f, 0.0f
    )

    init {
        vertexBuffer = ByteBuffer.allocateDirect(vertexData.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
            .put(vertexData).position(0) as FloatBuffer

        textureBuffer = ByteBuffer.allocateDirect(textureData.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
            .put(textureData).position(0) as FloatBuffer
    }

    fun setClear(clear: Boolean) {
        this.isClear = clear
    }

    fun onSurfaceCreated() {
        val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, AlphaShader.VERTEX_SHADER)
        val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, AlphaShader.FRAGMENT_SHADER)

        programId = GLES20.glCreateProgram().also {
            GLES20.glAttachShader(it, vertexShader)
            GLES20.glAttachShader(it, fragmentShader)
            GLES20.glLinkProgram(it)
        }

        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        textureId = textures[0]

        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        surfaceTexture = SurfaceTexture(textureId)
        onSurfaceReady(surfaceTexture!!)
    }

    fun drawFrame() {
        surfaceTexture?.let { st ->
            st.updateTexImage()

            // 基础防鬼影
            if (isClear) {
                GLES20.glClearColor(0f, 0f, 0f, 0f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                return
            }

            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            GLES20.glUseProgram(programId)

            val aPositionHandle = GLES20.glGetAttribLocation(programId, "aPosition")
            GLES20.glEnableVertexAttribArray(aPositionHandle)
            GLES20.glVertexAttribPointer(aPositionHandle, 2, GLES20.GL_FLOAT, false, 0, vertexBuffer)

            val aTexCoordHandle = GLES20.glGetAttribLocation(programId, "aTexCoord")
            GLES20.glEnableVertexAttribArray(aTexCoordHandle)
            GLES20.glVertexAttribPointer(aTexCoordHandle, 2, GLES20.GL_FLOAT, false, 0, textureBuffer)

            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
            GLES20.glUniform1i(GLES20.glGetUniformLocation(programId, "sTexture"), 0)

            GLES20.glEnable(GLES20.GL_BLEND)
            GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

            GLES20.glDisable(GLES20.GL_BLEND)
            GLES20.glDisableVertexAttribArray(aPositionHandle)
            GLES20.glDisableVertexAttribArray(aTexCoordHandle)
        }
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        return GLES20.glCreateShader(type).also { shader ->
            GLES20.glShaderSource(shader, shaderCode)
            GLES20.glCompileShader(shader)
        }
    }
}