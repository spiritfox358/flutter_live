package com.example.my_alpha_player.player

import android.content.Context
import android.graphics.SurfaceTexture
import android.util.AttributeSet
import android.view.TextureView

class AlphaTextureView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : TextureView(context, attrs), TextureView.SurfaceTextureListener {

    private var renderThread: RenderThread? = null

    // 回调
    var onSurfaceReady: ((SurfaceTexture) -> Unit)? = null
    var onFirstFrameVisible: (() -> Unit)? = null

    private val rendererDelegate = AlphaVideoRenderer(
        onSurfaceReady = { st -> onSurfaceReady?.invoke(st) },
        onFrameAvailable = {
            // 🟢 关键修改：当有新帧时，唤醒渲染线程
            renderThread?.notifyNewFrame()
        },
        onFirstFrameRendered = { post { onFirstFrameVisible?.invoke() } }
    )

    init {
        isOpaque = false
        surfaceTextureListener = this
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        startThread(surface, width, height)
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
        renderThread?.updateSize(width, height)
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        stopThread()
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) { }

    fun setClear(clear: Boolean) {
        // 如果是设为 Clear 模式，我们需要手动触发一次刷新，让屏幕变透明
        rendererDelegate.isClear = clear
        if (clear) {
            renderThread?.notifyNewFrame()
        }
    }

    fun setFilterParams(params: FilterParams) {
        rendererDelegate.currentParams = params
    }

    private fun startThread(surface: SurfaceTexture, w: Int, h: Int) {
        stopThread()
        renderThread = RenderThread(surface, rendererDelegate, w, h).apply {
            start()
        }
    }

    private fun stopThread() {
        renderThread?.exit()
        renderThread = null
    }

    private class RenderThread(
        private val surface: SurfaceTexture,
        private val renderer: AlphaVideoRenderer,
        private var width: Int,
        private var height: Int
    ) : Thread() {
        private var running = true
        private val lock = Object()
        private var frameAvailable = false

        // EGL 变量
        private var eglDisplay: javax.microedition.khronos.egl.EGLDisplay? = null
        private var eglContext: javax.microedition.khronos.egl.EGLContext? = null
        private var eglSurface: javax.microedition.khronos.egl.EGLSurface? = null
        private val egl = javax.microedition.khronos.egl.EGLContext.getEGL() as javax.microedition.khronos.egl.EGL10

        // 🟢 通知线程：有新一帧视频到了
        fun notifyNewFrame() {
            synchronized(lock) {
                frameAvailable = true
                lock.notifyAll()
            }
        }

        fun updateSize(w: Int, h: Int) {
            synchronized(lock) {
                width = w
                height = h
                // 尺寸变了也触发一次绘制
                frameAvailable = true
                lock.notifyAll()
            }
        }

        fun exit() {
            running = false
            synchronized(lock) {
                lock.notifyAll()
            }
            try { join(500) } catch (e: InterruptedException) { }
        }

        override fun run() {
            initGL()
            renderer.onSurfaceCreated()
            renderer.updateViewport(width, height)

            while (running) {
                synchronized(lock) {
                    // 🟢 核心逻辑：如果没有新帧，就挂起等待 (Wait)，不再空转
                    // 除非处于 Clear 模式(需要持续刷透明) 或 刚收到退出信号
                    while (running && !frameAvailable) {
                        try { lock.wait() } catch (e: InterruptedException) {}
                    }
                    if (!running) return@synchronized
                    frameAvailable = false
                }

                // 醒来后绘制一帧
                renderer.drawFrame()
                egl.eglSwapBuffers(eglDisplay, eglSurface)
            }
            shutdownGL()
        }

        private fun initGL() {
            eglDisplay = egl.eglGetDisplay(javax.microedition.khronos.egl.EGL10.EGL_DEFAULT_DISPLAY)
            egl.eglInitialize(eglDisplay, IntArray(2))
            val configAttribs = intArrayOf(
                javax.microedition.khronos.egl.EGL10.EGL_RED_SIZE, 8,
                javax.microedition.khronos.egl.EGL10.EGL_GREEN_SIZE, 8,
                javax.microedition.khronos.egl.EGL10.EGL_BLUE_SIZE, 8,
                javax.microedition.khronos.egl.EGL10.EGL_ALPHA_SIZE, 8,
                javax.microedition.khronos.egl.EGL10.EGL_RENDERABLE_TYPE, 4,
                javax.microedition.khronos.egl.EGL10.EGL_NONE
            )
            val configs = arrayOfNulls<javax.microedition.khronos.egl.EGLConfig>(1)
            val numConfigs = IntArray(1)
            egl.eglChooseConfig(eglDisplay, configAttribs, configs, 1, numConfigs)
            val attrib_list = intArrayOf(0x3098, 2, javax.microedition.khronos.egl.EGL10.EGL_NONE)
            eglContext = egl.eglCreateContext(eglDisplay, configs[0], javax.microedition.khronos.egl.EGL10.EGL_NO_CONTEXT, attrib_list)
            eglSurface = egl.eglCreateWindowSurface(eglDisplay, configs[0], surface, null)
            egl.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
        }

        private fun shutdownGL() {
            egl.eglMakeCurrent(eglDisplay, javax.microedition.khronos.egl.EGL10.EGL_NO_SURFACE, javax.microedition.khronos.egl.EGL10.EGL_NO_SURFACE, javax.microedition.khronos.egl.EGL10.EGL_NO_CONTEXT)
            egl.eglDestroySurface(eglDisplay, eglSurface)
            egl.eglDestroyContext(eglDisplay, eglContext)
            egl.eglTerminate(eglDisplay)
        }
    }
}