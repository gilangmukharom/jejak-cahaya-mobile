import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Kredensial penandatanganan ────────────────────────────────────────
//
// Dibaca dari `android/key.properties`, yang TIDAK ikut ke dalam repo. Kunci
// penandatanganan adalah satu-satunya benda di proyek ini yang tidak bisa
// dibuat ulang: Android menolak pembaruan yang tanda tangannya berbeda, jadi
// keystore yang hilang berarti setiap pengguna harus mencopot pemasangan
// lebih dulu sebelum bisa memperbarui.
//
// Ketiadaan berkas itu bukan galat. Orang lain yang mengambil repo ini harus
// tetap bisa menjalankan `flutter build apk --release` untuk mencoba sendiri;
// yang mereka dapat hanyalah APK bertanda tangan debug, dan blok `release`
// di bawah menyatakannya secara eksplisit alih-alih gagal dengan pesan yang
// membingungkan.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()

if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Tanpa keystore, build tetap jalan tetapi hasilnya hanya
                // layak untuk dicoba sendiri — Play Store menolaknya, dan ia
                // tidak bisa memperbarui pemasangan yang bertanda tangan rilis.
                logger.lifecycle(
                    "key.properties tidak ditemukan — APK release ditandatangani kunci debug.",
                )
                signingConfigs.getByName("debug")
            }

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
