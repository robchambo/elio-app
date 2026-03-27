plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.elio.elio_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.elio.elio_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ── Build flavours: dev / prod ────────────────────────────────
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Elio Dev")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Elio")
        }
    }

    buildTypes {
        release {
            // Debug signing for now; replace with release keystore before Play Store submission.
            signingConfig = signingConfigs.getByName("debug")
            manifestPlaceholders["firebaseCrashlyticsCollectionEnabled"] = true
            // Enable Crashlytics NDK crash reporting
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
        debug {
            // Disable Crashlytics in debug to keep build fast
            manifestPlaceholders["firebaseCrashlyticsCollectionEnabled"] = false
        }
    }
}

flutter {
    source = "../.."
}
