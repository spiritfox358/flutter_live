import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        // --- 1. 优先使用阿里云镜像 (下载速度快，不丢包) ---
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/jcenter") }

        // --- 2. 原有的仓库 (作为备选) ---
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }

        // --- 3. 显式加上 jcenter (有些老库只在这里有) ---
        jcenter()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// 放在 android/build.gradle 的最末尾
subprojects {
    // 监听 "com.android.library" 插件的应用
    pluginManager.withPlugin("com.android.library") {
        // 安全地配置 LibraryExtension
        extensions.configure<LibraryExtension> {
            // 如果插件没有声明 namespace (旧插件常见问题)
            if (namespace == null) {
                // 使用 group (通常是包名) 作为 namespace
                namespace = project.group.toString()
            }
        }
    }
}