pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 9.1.1, bukan 9.0.1: Compose 1.12 dan androidx.core 1.19 yang dibawa
    // SceneView (AR tokoh) menolak dibangun di bawah AGP 9.1.0. Sengaja
    // dinaikkan satu minor saja — cukup untuk syarat itu, dengan perubahan
    // perilaku sesedikit mungkin. Pasangannya Gradle 9.3.1 (gradle-wrapper).
    id("com.android.application") version "9.1.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Kompiler Compose untuk layar AR native (SceneView hanya menyediakan API
    // Compose). Versinya wajib sama persis dengan plugin Kotlin di atas.
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.20" apply false
}

include(":app")
