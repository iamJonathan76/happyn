allprojects {
    repositories {
        google()
        mavenCentral()
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

// Le module Android de sentry_flutter fige `languageVersion = "1.6"`, que le
// compilateur Kotlin 2.3 refuse (« Language version 1.6 is no longer
// supported »). On force la valeur pour ce seul module plutot que de
// retrograder Kotlin pour tout le projet : le reste de la chaine de build reste
// intact, et la surcharge disparaitra d'elle-meme quand le paquet sera mis a
// jour en amont.
subprojects {
    if (name == "sentry_flutter") {
        afterEvaluate {
            // Le module declare aussi compileSdk 34, alors que d'autres greffons
            // du projet exigent 36. Compiler contre une API plus recente ne
            // change ni le targetSdk ni le minSdk : aucun appareil n'est perdu.
            extensions.findByType<com.android.build.gradle.LibraryExtension>()
                ?.compileSdk = 36
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                .configureEach {
                    compilerOptions {
                        languageVersion.set(
                            org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0,
                        )
                        apiVersion.set(
                            org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0,
                        )
                    }
                }
        }
    }
}

// Le module Android de flutter_stripe fait echouer TOUT build de release sur
// `lintVitalAnalyzeRelease` : il declare une dependance de lint vers
// `com.google.android.gms:play-services-tapandpay:17.1.2`, qui n'est publie sur
// aucun depot public (ni Google, ni Maven Central) — c'est un artefact reserve
// au programme Google Pay push provisioning. Constate le 2026-10-05 : le build
// de release n'avait donc jamais abouti, et rien ne le signalait tant qu'on ne
// compilait qu'en debug.
//
// On exclut l'artefact des SEULES configurations de lint. Desactiver le lint
// ne suffit pas : Gradle resout le graphe de dependances avant de decider s'il
// execute la tache. Et exclure la dependance partout casserait le code de
// provisionnement de cartes dans Google Pay — une fonction de Stripe Issuing
// que HAPPYN n'utilise pas, mais dont la classe doit rester presente a
// l'execution pour ne pas lever de NoClassDefFoundError.
//
// Ce qu'on perd : les regles de lint apportees par ce paquet tiers. Ce qu'on
// garde : le lint sur notre propre code, et un binaire Stripe inchange.
//
// A retirer quand flutter_stripe cessera de declarer cette dependance.
subprojects {
    if (name == "stripe_android") {
        configurations.matching { it.name.contains("Lint", ignoreCase = true) }
            .configureEach {
                exclude(
                    group = "com.google.android.gms",
                    module = "play-services-tapandpay",
                )
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
