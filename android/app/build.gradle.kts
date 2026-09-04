plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.jejakcahaya.jejak_cahaya"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Diperlukan flutter_local_notifications: pustaka itu memakai API waktu
        // dari Java 8 (java.time) untuk menjadwalkan alarm, sementara Android
        // baru menyediakannya sejak API 26. Desugaring menuliskan ulang
        // pemanggilannya saat build sehingga tetap berjalan di perangkat lama.
        // Wajib dinyalakan meskipun aplikasi tidak memakai penjadwalan sama
        // sekali — tanpanya build gagal saat menautkan pustakanya.
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.jejakcahaya.jejak_cahaya"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // R8 berjalan pada build release dan TIDAK berjalan pada build
            // debug. Itulah mengapa kamera bisa menyala mulus lewat
            // `flutter run` tetapi mati pada APK hasil build: kelas CameraX
            // dan ML Kit yang hanya dipanggil lewat refleksi tidak terlihat
            // oleh R8, lalu dibuang. Aturan penjagaannya ada di
            // proguard-rules.pro di folder yang sama.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // Versinya disamakan dengan yang dipakai flutter_local_notifications; dua
    // versi desugar_jdk_libs yang berbeda dalam satu build akan bentrok.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
