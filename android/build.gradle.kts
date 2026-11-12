allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") } // CloudStream library (feature/extra)
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

// flutter_js compiles its Java sources for JVM 11 but its Kotlin task
// defaults to JVM 1.8. Align that module's Kotlin target with Java so Gradle's
// JVM-target validation passes. Reflection avoids adding a second KGP
// dependency to the root buildscript classpath.
subprojects {
    if (project.name == "flutter_js") {
        tasks.configureEach {
            if (this.name.endsWith("Kotlin")) {
                val kotlinOptions = javaClass.methods
                    .firstOrNull { it.name == "getKotlinOptions" && it.parameterCount == 0 }
                    ?.invoke(this)
                kotlinOptions?.javaClass?.methods
                    ?.firstOrNull { it.name == "setJvmTarget" && it.parameterCount == 1 }
                    ?.invoke(kotlinOptions, "11")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
