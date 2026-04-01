package com.example.hardcore_mixer

import android.graphics.SurfaceTexture
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.Matrix
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicIntegerArray
import java.util.concurrent.CountDownLatch
import kotlin.concurrent.thread

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay

class HardcoreRenderer(private val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry) {

    // 🚀 新增：这把锁用来让 OpenGL 线程在没有新画面时休眠，拯救 GPU！
    private val frameSync = Object()

    @Volatile private var isRunning = false
    val inputTextureIds = IntArray(9)
    val inputSurfaceTextures = arrayOfNulls<SurfaceTexture>(9)
    val inputSurfaces = arrayOfNulls<Surface>(9)
    val xformMatrices = Array(9) { FloatArray(16) }

    @Volatile var activeStreamCount = 0
    private val pendingFrames = AtomicIntegerArray(9)
    private val hasFirstFrame = BooleanArray(9)
    private var surfaceCallbackThread: HandlerThread? = null

    private val initLatch = CountDownLatch(1)
    @Volatile var currentLayouts = FloatArray(36) { 0f }

    @Volatile var containerW = 1080f
    @Volatile var containerH = 1920f

    @Volatile var videoRatios = FloatArray(9) { 9f / 16f }

    fun updateLayouts(layouts: FloatArray, w: Float, h: Float) {
        for (i in layouts.indices) {
            if (i < 36) currentLayouts[i] = layouts[i]
        }
        containerW = w
        containerH = h
    }

    fun updateVideoRatio(index: Int, ratio: Float) {
        if (index in 0..8) {
            videoRatios[index] = ratio
        }
    }

    private val vertexShaderCode = """
        attribute vec4 a_position;
        attribute vec2 a_texCoord;
        varying vec2 v_texCoord;
        void main() {
            gl_Position = a_position;
            v_texCoord = a_texCoord;
        }
    """.trimIndent()

    private val fragmentShaderCode = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        varying vec2 v_texCoord;
        
        uniform samplerExternalOES u_tex0; uniform samplerExternalOES u_tex1; uniform samplerExternalOES u_tex2;
        uniform samplerExternalOES u_tex3; uniform samplerExternalOES u_tex4; uniform samplerExternalOES u_tex5;
        uniform samplerExternalOES u_tex6; uniform samplerExternalOES u_tex7; uniform samplerExternalOES u_tex8;
        
        uniform mat4 u_xform0; uniform mat4 u_xform1; uniform mat4 u_xform2;
        uniform mat4 u_xform3; uniform mat4 u_xform4; uniform mat4 u_xform5;
        uniform mat4 u_xform6; uniform mat4 u_xform7; uniform mat4 u_xform8;

        uniform int u_hasFrame0; uniform int u_hasFrame1; uniform int u_hasFrame2;
        uniform int u_hasFrame3; uniform int u_hasFrame4; uniform int u_hasFrame5;
        uniform int u_hasFrame6; uniform int u_hasFrame7; uniform int u_hasFrame8;

        uniform int u_activeCount;
        uniform vec4 u_layouts[9]; 
        
        uniform float u_videoRatios[9];
        uniform float u_canvasRatio;

        vec2 dynamicCenterCrop(vec2 coord, float cellNormW, float cellNormH, float vidRatio) { 
            vec2 c = coord - vec2(0.5, 0.5); 
            float physicalCellRatio = (cellNormW / cellNormH) * u_canvasRatio;
            
            // 完美的 1:1 无损裁剪公式
            if (physicalCellRatio > vidRatio) {
                c.y *= vidRatio / physicalCellRatio;
            } else {
                c.x *= physicalCellRatio / vidRatio;
            }
            
            // 🚀🚀🚀 绝杀黑边！把你最早写的最牛逼的这行代码加回来！
            // 画面放大 15%，彻底切掉推流自带的恶心黑边！
            c *= 0.85; 
            
            return c + vec2(0.5, 0.5); 
        }

        #define CHECK_HIT(i) \
            if (i < u_activeCount) { \
                vec4 rect = u_layouts[i]; \
                if (uiX >= rect.x && uiX <= rect.x + rect.z && uiY >= rect.y && uiY <= rect.y + rect.w) { \
                    index = i; \
                    localCoord = vec2((uiX - rect.x) / rect.z, (uiY - rect.y) / rect.w); \
                    vidRatio = u_videoRatios[i]; \
                    cellW = rect.z; \
                    cellH = rect.w; \
                } \
            }

        void main() {
            vec4 color = vec4(0.0); 
            float uiY = 1.0 - v_texCoord.y; 
            float uiX = v_texCoord.x;
            
            int index = -1;
            vec2 localCoord = vec2(0.0);
            float vidRatio = 0.5625;
            float cellW = 1.0;
            float cellH = 1.0;

            CHECK_HIT(0); CHECK_HIT(1); CHECK_HIT(2);
            CHECK_HIT(3); CHECK_HIT(4); CHECK_HIT(5);
            CHECK_HIT(6); CHECK_HIT(7); CHECK_HIT(8);

            if (index != -1 && cellW > 0.001 && cellH > 0.001) {
                localCoord.y = 1.0 - localCoord.y;
                vec2 cropped = dynamicCenterCrop(localCoord, cellW, cellH, vidRatio);
                
                if (index == 0 && u_hasFrame0 == 1) color = texture2D(u_tex0, (u_xform0 * vec4(cropped, 0.0, 1.0)).xy);
                else if (index == 1 && u_hasFrame1 == 1) color = texture2D(u_tex1, (u_xform1 * vec4(cropped, 0.0, 1.0)).xy);
                else if (index == 2 && u_hasFrame2 == 1) color = texture2D(u_tex2, (u_xform2 * vec4(cropped, 0.0, 1.0)).xy);
                else if (index == 3 && u_hasFrame3 == 1) color = texture2D(u_tex3, (u_xform3 * vec4(cropped, 0.0, 1.0)).xy);
                else if (index == 4 && u_hasFrame4 == 1) color = texture2D(u_tex4, (u_xform4 * vec4(cropped, 0.0, 1.0)).xy);
                else if (index == 5 && u_hasFrame5 == 1) color = texture2D(u_tex5, (u_xform5 * vec4(cropped, 0.0, 1.0)).xy);
                else if (index == 6 && u_hasFrame6 == 1) color = texture2D(u_tex6, (u_xform6 * vec4(cropped, 0.0, 1.0)).xy);
                else if (index == 7 && u_hasFrame7 == 1) color = texture2D(u_tex7, (u_xform7 * vec4(cropped, 0.0, 1.0)).xy);
                else if (index == 8 && u_hasFrame8 == 1) color = texture2D(u_tex8, (u_xform8 * vec4(cropped, 0.0, 1.0)).xy);
            }
            gl_FragColor = color;
        }
    """.trimIndent()

    fun start() {
        if (isRunning) return
        isRunning = true
        surfaceCallbackThread = HandlerThread("OES_Callback_Thread").apply { start() }
        thread { renderLoop() }
        try { initLatch.await() } catch (e: Exception) {}
    }

    fun release() {
        isRunning = false
        surfaceCallbackThread?.quitSafely()
        surfaceCallbackThread = null
    }

    private fun renderLoop() {
        val callbackHandler = Handler(surfaceCallbackThread!!.looper)

        val eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        EGL14.eglInitialize(eglDisplay, version, 0, version, 1)

        val attribList = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, 1, numConfigs, 0)

        val eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)

        val outputSurfaceTexture = flutterTextureEntry.surfaceTexture()
        val outputSurface = Surface(outputSurfaceTexture)

        val eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, configs[0], outputSurface, intArrayOf(EGL14.EGL_NONE), 0)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)

        GLES20.glGenTextures(9, inputTextureIds, 0)
        for (i in 0 until 9) {
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, inputTextureIds[i])
            GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR.toFloat())
            GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR.toFloat())
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

            inputSurfaceTextures[i] = SurfaceTexture(inputTextureIds[i]).apply {
                setOnFrameAvailableListener({
                    pendingFrames.incrementAndGet(i)
                    // 🚀 性能修复 1：收到新画面，立刻踹醒 OpenGL 渲染线程！
                    synchronized(frameSync) { frameSync.notifyAll() }
                }, callbackHandler)
            }
            inputSurfaces[i] = Surface(inputSurfaceTextures[i])
            hasFirstFrame[i] = false
            Matrix.setIdentityM(xformMatrices[i], 0)
        }

        initLatch.countDown()

        val program = GLES20.glCreateProgram()
        val vShader = GLES20.glCreateShader(GLES20.GL_VERTEX_SHADER).also {
            GLES20.glShaderSource(it, vertexShaderCode)
            GLES20.glCompileShader(it)
            GLES20.glAttachShader(program, it)
        }
        val fShader = GLES20.glCreateShader(GLES20.GL_FRAGMENT_SHADER).also {
            GLES20.glShaderSource(it, fragmentShaderCode)
            GLES20.glCompileShader(it)
            GLES20.glAttachShader(program, it)
        }
        GLES20.glLinkProgram(program)

        val vertexData = floatArrayOf(-1.0f,1.0f,0.0f,1.0f, -1.0f,-1.0f,0.0f,0.0f, 1.0f,1.0f,1.0f,1.0f, 1.0f,-1.0f,1.0f,0.0f)
        val vertexBuffer = ByteBuffer.allocateDirect(vertexData.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().put(vertexData).apply { position(0) }
        val posHandle = GLES20.glGetAttribLocation(program, "a_position")
        val texHandle = GLES20.glGetAttribLocation(program, "a_texCoord")

        val countHandle = GLES20.glGetUniformLocation(program, "u_activeCount")
        val layoutsHandle = GLES20.glGetUniformLocation(program, "u_layouts")
        val canvasRatioHandle = GLES20.glGetUniformLocation(program, "u_canvasRatio")
        val videoRatiosHandle = GLES20.glGetUniformLocation(program, "u_videoRatios")

        var lastW = 0f
        var lastH = 0f

        while (isRunning) {
            // 🚀 性能修复 2：检查是否有任何流传来了新帧
            var hasNewFrame = false
            for (i in 0 until 9) {
                if (pendingFrames.get(i) > 0) {
                    hasNewFrame = true
                    break
                }
            }

            // 🚀 性能修复 3：如果没有新帧，立刻休眠，绝对不空跑 GPU！最多睡 50ms 兜底。
            if (!hasNewFrame) {
                synchronized(frameSync) {
                    try {
                        frameSync.wait(50)
                    } catch (e: InterruptedException) {}
                }
                continue // 醒来后重新从 while 开始检查
            }

            if (containerW != lastW || containerH != lastH) {
                if (containerW > 0 && containerH > 0) {
                    outputSurfaceTexture.setDefaultBufferSize(containerW.toInt(), containerH.toInt())
                    lastW = containerW
                    lastH = containerH
                }
            }

            for (i in 0 until 9) {
                var updated = false
                while (pendingFrames.get(i) > 0) {
                    try {
                        GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + i)
                        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, inputTextureIds[i])
                        inputSurfaceTextures[i]?.updateTexImage()
                        pendingFrames.decrementAndGet(i)
                        updated = true
                    } catch (e: Exception) {
                        pendingFrames.set(i, 0); break
                    }
                }
                if (updated) {
                    inputSurfaceTextures[i]?.getTransformMatrix(xformMatrices[i])
                    hasFirstFrame[i] = true
                }
            }

            GLES20.glViewport(0, 0, containerW.toInt(), containerH.toInt())
            GLES20.glClearColor(0f, 0f, 0f, 0f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            GLES20.glUseProgram(program)

            GLES20.glUniform1i(countHandle, activeStreamCount)
            GLES20.glUniform4fv(layoutsHandle, 9, currentLayouts, 0)
            GLES20.glUniform1f(canvasRatioHandle, containerW / containerH)
            GLES20.glUniform1fv(videoRatiosHandle, 9, videoRatios, 0)

            for (i in 0 until 9) {
                GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + i)
                GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, inputTextureIds[i])
                GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "u_tex$i"), i)
                GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program, "u_xform$i"), 1, false, xformMatrices[i], 0)
                GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "u_hasFrame$i"), if (hasFirstFrame[i]) 1 else 0)
            }

            vertexBuffer.position(0)
            GLES20.glVertexAttribPointer(posHandle, 2, GLES20.GL_FLOAT, false, 4 * 4, vertexBuffer)
            GLES20.glEnableVertexAttribArray(posHandle)

            vertexBuffer.position(2)
            GLES20.glVertexAttribPointer(texHandle, 2, GLES20.GL_FLOAT, false, 4 * 4, vertexBuffer)
            GLES20.glEnableVertexAttribArray(texHandle)

            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            EGL14.eglSwapBuffers(eglDisplay, eglSurface)
            // 🚀 性能修复 4：已经删除了导致死循环空耗的 Thread.sleep(16)
        }

        EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
        EGL14.eglDestroySurface(eglDisplay, eglSurface)
        EGL14.eglDestroyContext(eglDisplay, eglContext)
        EGL14.eglReleaseThread()
        EGL14.eglTerminate(eglDisplay)
        outputSurface.release()
    }
}