// web/alpha_player_web.js

// 🟢 1. 一级缓存：内存 RAM (Map)
// 页面关闭即销毁，但读取最快，适合连击
const gRamCache = new Map();

// 🟢 2. 二级缓存：持久化 IndexedDB
const VideoDB = {
    dbName: "AlphaPlayerCacheDB",
    storeName: "videos",
    db: null,
    async open() {
        if (this.db) return this.db;
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(this.dbName, 1);
            request.onupgradeneeded = (e) => {
                const db = e.target.result;
                if (!db.objectStoreNames.contains(this.storeName)) db.createObjectStore(this.storeName);
            };
            request.onsuccess = (e) => { this.db = e.target.result; resolve(this.db); };
            request.onerror = () => reject("DB Error");
        });
    },
    async getVideo(url) {
        try {
            await this.open();
            return new Promise((resolve) => {
                const tx = this.db.transaction([this.storeName], "readonly");
                const req = tx.objectStore(this.storeName).get(url);
                req.onsuccess = () => resolve(req.result);
                req.onerror = () => resolve(undefined);
            });
        } catch (e) { return undefined; }
    },
    async saveVideo(url, blob) {
        try {
            await this.open();
            const tx = this.db.transaction([this.storeName], "readwrite");
            tx.objectStore(this.storeName).put(blob, url);
        } catch (e) { console.warn("DB Save Failed", e); }
    }
};

class AlphaVideoPlayer {
    constructor(viewId) {
        this.viewId = viewId;
        this.canvas = document.createElement('canvas');
        this.canvas.style.width = '100%';
        this.canvas.style.height = '100%';

        const glAttributes = { alpha: true, premultipliedAlpha: false, antialias: true, preserveDrawingBuffer: false };
        this.gl = this.canvas.getContext('webgl', glAttributes) || this.canvas.getContext('experimental-webgl', glAttributes);

        this.video = document.createElement('video');
        this.video.crossOrigin = "anonymous";
        this.video.muted = false;
        this.video.volume = 1.0;
        this.video.playsInline = true;
        // 关键：预加载元数据，加快起播
        this.video.preload = "auto";

        this.isPlaying = false;
        this.animationFrameId = null;
        this.onEndedCallback = null;
        // 标记是否已经解锁了声音上下文
        this.isAudioUnlocked = false;

        this.params = { hue: 0.0, isOn: 0.0 };
        this.initGL();

        // 🟢 监听全局点击：只要用户点过一次屏幕，就解锁声音
        const unlockAudio = () => {
            if (this.isAudioUnlocked) return;
            // 播放一个极短的静音片段来获取浏览器信任
            this.video.muted = false;
            const p = this.video.play();
            if (p !== undefined) {
                p.then(() => {
                    this.video.pause();
                    this.isAudioUnlocked = true;
                    console.log("🔓 Audio Context Unlocked!");
                }).catch(() => {});
            }
            window.removeEventListener('click', unlockAudio);
            window.removeEventListener('touchstart', unlockAudio);
        };
        window.addEventListener('click', unlockAudio);
        window.addEventListener('touchstart', unlockAudio);

        this.video.addEventListener('canplay', () => {
             if (this.isPlaying) return; // 防止重复调用
             this.canvas.width = this.video.videoWidth / 2;
             this.canvas.height = this.video.videoHeight;
             this.gl.viewport(0, 0, this.canvas.width, this.canvas.height);

             // 🟢 鲁棒的播放逻辑：双重保底
             const playPromise = this.video.play();
             if (playPromise !== undefined) {
                 playPromise.then(() => {
                     // ✅ 正常播放
                     this.isPlaying = true;
                     this.render();
                 })
                 .catch(error => {
                     console.warn("⚠️ 自动播放被拦截 (NotAllowedError)，降级为静音播放以保住连击:", error);
                     // ❌ 失败：切换静音再试一次
                     this.video.muted = true;
                     this.video.play().then(() => {
                         this.isPlaying = true;
                         this.render();
                     }).catch(err2 => {
                         // ❌❌ 彻底失败 (极少见)：直接跳过，防止队列卡死
                         console.error("❌ 彻底无法播放，跳过此礼物", err2);
                         this._triggerEnded();
                     });
                 });
             }
        });

        this.video.addEventListener('ended', () => {
            console.log("✅ Video Ended");
            this._triggerEnded();
        });

        // 增加错误监听，防止解码错误卡死队列
        this.video.addEventListener('error', (e) => {
            console.error("❌ Video Error", e);
            this._triggerEnded();
        });
    }

    _triggerEnded() {
        this.isPlaying = false;
        if (this.onEndedCallback) {
            // 稍微延迟一点，确保最后一帧渲染完成
            // setTimeout(() => this.onEndedCallback(), 0);
            this.onEndedCallback();
        }
    }

    getDomElement() { return this.canvas; }

    setOnEnded(callback) {
        this.onEndedCallback = callback;
    }

    // 🟢 核心：双管齐下加载逻辑
    async play(url, hue) {
        if (hue !== null && hue !== undefined) {
            this.params.hue = hue;
            this.params.isOn = 1.0;
        } else {
            this.params.isOn = 0.0;
        }

        // 重置状态
        this.isPlaying = false;
        // 如果之前解锁过，或者这次是用户主动操作，尝试开声音
        // 如果没解锁，为了保险，可以默认静音，或者尝试开声音由 catch 捕获
        this.video.muted = false;

        try {
            // 1. 🚀 检查 RAM (一级缓存)
            if (gRamCache.has(url)) {
                console.log("⚡ [RAM Hit] 内存直出:", url);
                this.video.src = gRamCache.get(url);
                this.video.load();
                return;
            }

            // 2. 🔍 检查 DB (二级缓存)
            const cachedBlob = await VideoDB.getVideo(url);
            if (cachedBlob) {
                console.log("💾 [DB Hit] 硬盘读取 -> 写入内存:", url);
                const blobUrl = URL.createObjectURL(cachedBlob);

                // 写入 RAM，下次就是 0ms 了
                gRamCache.set(url, blobUrl);

                this.video.src = blobUrl;
                this.video.load();
                return;
            }

            // 3. ☁️ 网络下载 (三级兜底)
            console.log("⬇️ [Network] 下载中:", url);
            const response = await fetch(url);
            if (!response.ok) throw new Error("Net Error");
            const blob = await response.blob();

            // 存 DB
            VideoDB.saveVideo(url, blob);

            // 存 RAM
            const blobUrl = URL.createObjectURL(blob);
            gRamCache.set(url, blobUrl);

            this.video.src = blobUrl;
            this.video.load();

        } catch (e) {
            console.error("❌ 加载流程异常，尝试直接播放链接", e);
            // 最后的保底：直接赋 URL
            this.video.src = url;
            this.video.load();
        }
    }

    stop() {
        this.video.pause();
        this.isPlaying = false;
        if (this.animationFrameId) cancelAnimationFrame(this.animationFrameId);
        this.gl.clear(this.gl.COLOR_BUFFER_BIT);
    }

    render() {
        if (!this.isPlaying) return;
        const gl = this.gl;
        gl.useProgram(this.program);
        gl.bindTexture(gl.TEXTURE_2D, this.texture);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, this.video);

        const loc = (n) => gl.getUniformLocation(this.program, n);
        gl.uniform1f(loc('uHue'), this.params.hue);
        gl.uniform1f(loc('uSat'), this.params.sat);
        gl.uniform1f(loc('uVal'), this.params.val);
        gl.uniform1f(loc('uShadow'), this.params.shadow);
        gl.uniform1f(loc('uGamma'), this.params.gamma);
        gl.uniform1f(loc('uInLow'), this.params.inLow);
        gl.uniform1f(loc('uMixOrigin'), this.params.mixOrigin);
        gl.uniform1f(loc('uTintOn'), this.params.isOn);

        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
        this.animationFrameId = requestAnimationFrame(() => this.render());
    }

    initGL() {
        const gl = this.gl;
        const vsSource = `
            attribute vec2 a_position;
            attribute vec2 a_texCoord;
            varying vec2 v_texCoord;
            void main() {
                gl_Position = vec4(a_position, 0.0, 1.0);
                v_texCoord = a_texCoord;
            }
        `;

        const fsSource = `
            precision highp float;
            varying vec2 v_texCoord;
            uniform sampler2D u_texture;
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
                vec2 alphaUV = vec2(v_texCoord.x * 0.5, v_texCoord.y);
                vec2 colorUV = vec2(v_texCoord.x * 0.5 + 0.5, v_texCoord.y);
                vec4 originColor = texture2D(u_texture, colorUV);
                float alpha = texture2D(u_texture, alphaUV).r;

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
        `;

        const vertexShader = this.createShader(gl, gl.VERTEX_SHADER, vsSource);
        const fragmentShader = this.createShader(gl, gl.FRAGMENT_SHADER, fsSource);
        this.program = this.createProgram(gl, vertexShader, fragmentShader);

        const positionBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0]), gl.STATIC_DRAW);

        const texCoordBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, texCoordBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0]), gl.STATIC_DRAW);

        this.locPosition = gl.getAttribLocation(this.program, "a_position");
        this.locTexCoord = gl.getAttribLocation(this.program, "a_texCoord");

        gl.enableVertexAttribArray(this.locPosition);
        gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
        gl.vertexAttribPointer(this.locPosition, 2, gl.FLOAT, false, 0, 0);

        gl.enableVertexAttribArray(this.locTexCoord);
        gl.bindBuffer(gl.ARRAY_BUFFER, texCoordBuffer);
        gl.vertexAttribPointer(this.locTexCoord, 2, gl.FLOAT, false, 0, 0);

        this.texture = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, this.texture);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    }
    enableAtt(p,n,b){ const l=this.gl.getAttribLocation(p,n); this.gl.enableVertexAttribArray(l); this.gl.bindBuffer(this.gl.ARRAY_BUFFER,b); this.gl.vertexAttribPointer(l,2,this.gl.FLOAT,false,0,0); }
    createShader(gl,t,s){ const o=gl.createShader(t); gl.shaderSource(o,s); gl.compileShader(o); return o; }
    createProgram(gl,v,f){ const p=gl.createProgram(); gl.attachShader(p,v); gl.attachShader(p,f); gl.linkProgram(p); return p; }
}

window.AlphaPlayerWeb = { create: (id) => new AlphaVideoPlayer(id) };