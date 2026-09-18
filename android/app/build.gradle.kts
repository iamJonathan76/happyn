plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (notifications push) seulement si google-services.json est present.
//
// Ce fichier est volontairement hors du depot (.gitignore) : il identifie notre
// projet Firebase et n'a rien a faire dans un historique git. Consequence : un
// clone neuf ne l'a pas. Applique sans condition, le plugin faisait echouer
// toute la compilation — alors que l'app sait tourner sans Firebase
// (PushService echoue proprement et le reste fonctionne). Sans le fichier, on
// compile donc sans push, avec un avertissement plutot qu'un echec.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn(
        "google-services.json absent : compilation SANS notifications push. " +
            "Demande le fichier a l'equipe et place-le dans android/app/."
    )
}

android {
    namespace = "com.happyn.happyn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.happyn.happyn"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // APK de dev/test : pas de minification R8 (évite les soucis de
            // règles ProGuard de flutter_stripe/mobile_scanner). Pour un build
            // de prod (Play), on réactivera avec les bonnes keep rules.
            isMinifyEnabled = false
            isShrinkResources = false
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