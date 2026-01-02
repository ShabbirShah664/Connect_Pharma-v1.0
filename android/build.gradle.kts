allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Default build directory is used
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
