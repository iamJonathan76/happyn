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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
