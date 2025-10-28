plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // 🔥 Plugin de Google Services para leer google-services.json
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.wai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Application ID: este debe coincidir con el que registraste en Firebase
        applicationId = "com.example.wai"

        minSdk = flutter.minSdkVersion      
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Cambiar por una firma real si vas a publicar en Play Store
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔥 Firebase BoM asegura versiones compatibles
    implementation(platform("com.google.firebase:firebase-bom:34.2.0"))

    // Ejemplo de SDKs nativos de Firebase (opcionales)
    implementation("com.google.firebase:firebase-analytics")
    // ⚠️ El resto (Auth, Firestore, Storage, Messaging) ya los manejas desde pubspec.yaml
}
