package com.example.my_alpha_player

import android.content.Context
import android.graphics.PixelFormat
import android.graphics.SurfaceTexture
import android.opengl.GLSurfaceView
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class AlphaTextureView(context: Context) : GLSurfaceView(context), GLSurfaceView.Renderer {

    private var surfaceTextureListener: OnSurfaceTextureListener? = null
    private var currentSurfaceTexture: SurfaceTexture? = null

    private val rendererDelegate = AlphaVideoRenderer { st ->
        this.currentSurfaceTexture = st
        surfaceTextureListener?.onSurfaceTextureAvailable(st)
    }

    init {
        setEGLContextClientVersion(2)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        holder.setFormat(PixelFormat.TRANSLUCENT)
        setZOrderOnTop(true)
        setRenderer(this)
        renderMode = RENDERMODE_WHEN_DIRTY
    }

    // ✅ 恢复稳妥的写法：使用 queueEvent 确保线程安全
    fun setClear(clear: Boolean) {
        queueEvent {
            rendererDelegate.setClear(clear)
            requestRender()
        }
    }

    fun setOnSurfaceTextureListener(listener: OnSurfaceTextureListener) {
        this.surfaceTextureListener = listener
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        rendererDelegate.onSurfaceCreated()
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        android.opengl.GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        rendererDelegate.drawFrame()
    }

    interface OnSurfaceTextureListener {
        fun onSurfaceTextureAvailable(surfaceTexture: SurfaceTexture)
    }
}