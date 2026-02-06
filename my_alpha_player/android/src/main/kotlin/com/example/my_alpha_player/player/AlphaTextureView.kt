package com.example.my_alpha_player.player

import android.content.Context
import android.graphics.PixelFormat
import android.graphics.SurfaceTexture
import android.opengl.GLSurfaceView
import android.util.AttributeSet

class AlphaTextureView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : GLSurfaceView(context, attrs), GLSurfaceView.Renderer {

    // 🌟 这里是修正的关键：通过回调暴露 Surface
    var onSurfaceReady: ((SurfaceTexture) -> Unit)? = null

    private val rendererDelegate = AlphaVideoRenderer { st ->
        onSurfaceReady?.invoke(st)
    }

    init {
        setEGLContextClientVersion(2)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        holder.setFormat(PixelFormat.TRANSLUCENT)
        setZOrderOnTop(true)
        setRenderer(this)
        renderMode = RENDERMODE_WHEN_DIRTY
    }

    // 防鬼影方法
    fun setClear(clear: Boolean) {
        rendererDelegate.isClear = clear
        if (clear) {
            requestRender()
        }
    }

    // 调色参数设置方法
    fun setFilterParams(params: FilterParams) {
        rendererDelegate.currentParams = params
        requestRender()
    }

    override fun onSurfaceCreated(gl: javax.microedition.khronos.opengles.GL10?, config: javax.microedition.khronos.egl.EGLConfig?) { rendererDelegate.onSurfaceCreated() }
    override fun onSurfaceChanged(gl: javax.microedition.khronos.opengles.GL10?, width: Int, height: Int) { android.opengl.GLES20.glViewport(0, 0, width, height) }
    override fun onDrawFrame(gl: javax.microedition.khronos.opengles.GL10?) { rendererDelegate.drawFrame() }
}