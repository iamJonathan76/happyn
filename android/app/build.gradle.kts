import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Cle de signature de publication.
//
// Google Play refuse un APK signe avec la cle de debogage : elle est publique,
// identique sur toutes les machines, et n'identifie donc personne. La vraie
// cle vit dans android/key.properties, hors du depot (.gitignore).
//
// ⚠️ Cette cle est IRREMPLACABLE. Si elle est perdue, plus aucune mise a jour
//    de l'app ne peut etre publiee sous le meme identifiant — il faut
//    republier une nouvelle app et les utilisateurs ne migrent pas. La
//    sauvegarder ailleurs que sur ce portable fait partie du travail.
//
// Absente, on retombe sur la signature de debogage : un clone neuf compile et
// s'installe normalement, comme pour google-services.json. On ne peut
// simplement pas publier depuis cette machine-la.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

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

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "key.properties absent : build signe en DEBUG. " +
                        "Utilisable pour tester, REFUSE par Google Play."
                )
                signingConfigs.getByName("debug")
            }
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