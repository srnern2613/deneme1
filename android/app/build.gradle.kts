plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Hesap Sistemi — Firebase. google-services.json henüz eklenmedi (Firebase
// Console kurulumu sonraya bırakıldı) — bu yüzden plugin'i plugins{} bloğunda
// SABİT uygulamak yerine, dosya gerçekten var olduğunda koşullu olarak
// uyguluyoruz. Böylece proje bugün, Firebase olmadan da normal derlenir;
// google-services.json bu klasöre (android/app/) eklendiği an otomatik
// devreye girer, ekstra bir kod değişikliği gerekmez.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.example.deneme1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play Store / Firebase Console'un gördüğü GERÇEK, kalıcı kimlik bu —
        // Flutter'ın varsayılan placeholder'ından değiştirildi. NOT:
        // `namespace` (yukarıda) ve MainActivity.kt'nin gerçek Kotlin paket
        // klasörü kasıtlı olarak "com.example.deneme1" bırakıldı — bu, cihaz
        // köprüsünün derinlik sınırı yüzünden o dosyaya ulaşılamamasından
        // kaynaklanıyor, AMA `applicationId`in `namespace`'ten farklı olması
        // Android Gradle Plugin'de tamamen desteklenen, yaygın bir kurulum;
        // Play Store/Firebase sadece applicationId'yi görür, hiçbir işlevsel
        // sorun yaratmaz.
        applicationId = "com.draconiclingua.ignis"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
