plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}
val pluginName = "BlackGunsHandTracking"
val pluginPackageName = "com.blackguns.handtracking"
android {
    namespace = pluginPackageName
    compileSdk = 35
    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = pluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
        buildConfigField("String", "GODOT_PLUGIN_NAME", "\"$pluginName\"")
        setProperty("archivesBaseName", pluginName)
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    sourceSets["main"].assets.srcDir("src/main/assets")
}
dependencies {
    implementation("org.godotengine:godot:4.4.1.stable")
    implementation("com.google.mediapipe:tasks-vision:0.10.26")
}
val modelUrl = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
val modelFile = file("src/main/assets/hand_landmarker.task")
tasks.register("downloadHandModel") {
    outputs.file(modelFile)
    doLast {
        if (!modelFile.exists()) {
            modelFile.parentFile.mkdirs()
            java.net.URL(modelUrl).openStream().use { input ->
                modelFile.outputStream().use { output -> input.copyTo(output) }
            }
        }
    }
}
tasks.named("preBuild").configure { dependsOn("downloadHandModel") }
