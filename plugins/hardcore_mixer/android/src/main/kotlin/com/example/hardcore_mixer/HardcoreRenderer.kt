package com.example.hardcore_mixer

import android.graphics.SurfaceTexture
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.Matrix
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicIntegerArray
import kotlin.concurrent.thread

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface

class HardcoreRenderer(private val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry) {

    private val TAG = "HardcoreRenderer"
    @Volatile private var isRunning = false

    val inputTextureIds = IntArray(9)
    val inputSurfaceTextures = arrayOfNulls<SurfaceTexture>(9)
    val inputSurfaces = arrayOfNulls<Surface>(9)
    val xformMatrices = Array(9) { FloatArray(16) }

    @Volatile var activeStreamCount = 0

    private val frameAvailable = AtomicIntegerArray(9)
    // 🚀 核心修复 1：记录每个视频通道是否已经收到了“第一帧”
    private val pendingFrames = AtomicIntegerArray(9)
    private val hasFirstFrame = BooleanArray(9)
    private var surfaceCallbackThread: HandlerThread? = null

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

        // 🚀 核心升级：智能感知格子长宽比 + 自动吃黑边算法！
        vec2 dynamicCenterCrop(vec2 coord, float cellRatio) { 
            vec2 c = coord - vec2(0.5, 0.5); 
            float videoRatio = 9.0 / 16.0; // 0.5625
            
            // 1. 先进行完美的比例对齐（防拉伸变形）
            if (cellRatio > videoRatio) {
                c.y *= videoRatio / cellRatio;
            } else {
                c.x *= cellRatio / videoRatio;
            }
            
            // 🚀🚀🚀 2. 终极黑边杀手：统一向中心放大画面！
            // 乘以 0.85 意味着抽取中心 85% 的有效画面，强行放大填满格子，完美切掉四周的黑边！
            // 如果你的黑边特别大，可以把 0.85 改成 0.80 甚至更小。 以后改回 c *= 1.0;
            c *= 0.85; 
            
            return c + vec2(0.5, 0.5); 
        }

        void main() {
            vec4 color = vec4(0.0); 
            
            float uiY = 1.0 - v_texCoord.y; 
            float uiX = v_texCoord.x;
            
            int index = -1;
            vec2 localCoord = vec2(0.0);
            float cellRatio = 1.0; // 记录当前格子的长宽比例 (宽/高)

            // ==========================================
            // 🎨 精准复刻 Flutter Flex 布局并计算格子比例
            // ==========================================
            if (u_activeCount == 9) { 
                float col = floor(uiX * 3.0); float row = floor(uiY * 3.0);
                index = int(row * 3.0 + col); localCoord = vec2(fract(uiX * 3.0), fract(uiY * 3.0));
                cellRatio = 1.0; // 3/3
            } else if (u_activeCount == 8) { 
                float col = floor(uiX * 4.0); float row = floor(uiY * 2.0);
                index = int(row * 4.0 + col); localCoord = vec2(fract(uiX * 4.0), fract(uiY * 2.0));
                cellRatio = 0.5; // 2/4
            } else if (u_activeCount == 7) { 
                float row = floor(uiY * 2.0);
                if (row == 0.0) { 
                    float col = floor(uiX * 3.0); index = int(col); 
                    localCoord = vec2(fract(uiX * 3.0), fract(uiY * 2.0)); cellRatio = 0.6666; // 2/3
                } else { 
                    float col = floor(uiX * 4.0); index = 3 + int(col); 
                    localCoord = vec2(fract(uiX * 4.0), fract(uiY * 2.0)); cellRatio = 0.5; // 2/4
                }
            } else if (u_activeCount == 6) { 
                float col = floor(uiX * 3.0); float row = floor(uiY * 2.0);
                index = int(row * 3.0 + col); localCoord = vec2(fract(uiX * 3.0), fract(uiY * 2.0));
                cellRatio = 0.6666; // 2/3
            } else if (u_activeCount == 5) { 
                float row = floor(uiY * 2.0);
                if (row == 0.0) { 
                    float col = floor(uiX * 2.0); index = int(col); 
                    localCoord = vec2(fract(uiX * 2.0), fract(uiY * 2.0)); cellRatio = 1.0; // 2/2
                } else { 
                    float col = floor(uiX * 3.0); index = 2 + int(col); 
                    localCoord = vec2(fract(uiX * 3.0), fract(uiY * 2.0)); cellRatio = 0.6666; // 2/3
                }
            } else if (u_activeCount == 4) { 
                float col = floor(uiX * 2.0); float row = floor(uiY * 2.0);
                index = int(row * 2.0 + col); localCoord = vec2(fract(uiX * 2.0), fract(uiY * 2.0));
                cellRatio = 1.0; // 2/2
            } else if (u_activeCount == 3) { 
                if (uiX < 0.5) { 
                    index = 0; localCoord = vec2(uiX * 2.0, uiY); cellRatio = 0.5; // 1/2
                } else { 
                    float row = floor(uiY * 2.0); index = 1 + int(row); 
                    localCoord = vec2((uiX - 0.5) * 2.0, fract(uiY * 2.0)); cellRatio = 1.0; // 2/2
                }
            } else if (u_activeCount == 2) { 
                float col = floor(uiX * 2.0); index = int(col); localCoord = vec2(fract(uiX * 2.0), uiY);
                cellRatio = 0.5; // 1/2
            } else if (u_activeCount == 1) { 
                index = 0; localCoord = vec2(uiX, uiY);
                cellRatio = 1.0;
            }

            if (index != -1) {
                localCoord.y = 1.0 - localCoord.y;
                // 传入刚才动态算出的该格子的正确长宽比例
                vec2 cropped = dynamicCenterCrop(localCoord, cellRatio);
                
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

        // 开启专属回调线程
        surfaceCallbackThread = HandlerThread("OES_Callback_Thread").apply { start() }

        thread { renderLoop() }
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
        outputSurfaceTexture.setDefaultBufferSize(1080, 1080)
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
                    // 🚀 核心修复 2：只要来一帧，计数器就 +1
                    pendingFrames.incrementAndGet(i)
                }, callbackHandler)
            }
            inputSurfaces[i] = Surface(inputSurfaceTextures[i])
            hasFirstFrame[i] = false
            Matrix.setIdentityM(xformMatrices[i], 0)
        }

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

        val vertexData = floatArrayOf(
            -1.0f,  1.0f,   0.0f, 1.0f,
            -1.0f, -1.0f,   0.0f, 0.0f,
            1.0f,  1.0f,   1.0f, 1.0f,
            1.0f, -1.0f,   1.0f, 0.0f
        )
        val vertexBuffer = ByteBuffer.allocateDirect(vertexData.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().put(vertexData).apply { position(0) }
        val posHandle = GLES20.glGetAttribLocation(program, "a_position")
        val texHandle = GLES20.glGetAttribLocation(program, "a_texCoord")
        val countHandle = GLES20.glGetUniformLocation(program, "u_activeCount")

        while (isRunning) {
            for (i in 0 until 9) {
                var updated = false

                // 🚀🚀🚀 核心修复 3：抽水泵算法！
                // 只要队列里有积压的帧，就一直死循环把它抽干，绝不让底层解码器憋死！
                while (pendingFrames.get(i) > 0) {
                    try {
                        // 极其重要：更新前必须先激活它自己的坑位，防止踩踏！
                        GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + i)
                        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, inputTextureIds[i])

                        inputSurfaceTextures[i]?.updateTexImage()
                        pendingFrames.decrementAndGet(i) // 抽走一帧，计数器 -1
                        updated = true
                    } catch (e: Exception) {
                        pendingFrames.set(i, 0) // 如果报错，直接清零防死循环
                        break
                    }
                }

                // 只要这 16ms 内抽到过画面，就更新一次矩阵和状态
                if (updated) {
                    inputSurfaceTextures[i]?.getTransformMatrix(xformMatrices[i])
                    hasFirstFrame[i] = true
                }
            }

            GLES20.glClearColor(0f, 0f, 0f, 0f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            GLES20.glUseProgram(program)
            GLES20.glUniform1i(countHandle, activeStreamCount)

            // 绑定纹理、矩阵，并告诉 GPU 哪些视频是安全的
            for (i in 0 until 9) {
                GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + i)
                GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, inputTextureIds[i])
                GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "u_tex$i"), i)

                GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program, "u_xform$i"), 1, false, xformMatrices[i], 0)

                // 将安全状态告诉 GPU 的片段着色器
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
            Thread.sleep(16)
        }

        EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
        EGL14.eglDestroySurface(eglDisplay, eglSurface)
        EGL14.eglDestroyContext(eglDisplay, eglContext)
        EGL14.eglReleaseThread()
        EGL14.eglTerminate(eglDisplay)
        outputSurface.release()
        Log.d(TAG, "OpenGL 渲染线程已安全退出")
    }
}