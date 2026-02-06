package com.example.my_alpha_player.player

// ✨ 所有参数都是变量，不再写死在 Shader 里
data class FilterParams(
    var hue: Float = 0.78f,       // 色相 (紫色)
    var sat: Float = 1.0f,        // 浓度 (饱满)
    var value: Float = 1.1f,      // 亮度 (通透)
    var shadow: Float = 0.15f,    // 暗部提亮 (防死黑)
    var gamma: Float = 0.8f,      // 中间调 (柔和)
    var inLow: Float = 0.0f,      // 黑阶 (保留全部细节)
    var mixOrigin: Float = 0.0f,  // 原图混合 (纯色模式)
    var isOn: Boolean = true      // 开关
)