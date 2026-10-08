pluginManagement {
    repositories {
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}

rootProject.name = "TransliterationKit"

include(":transliterationkit-android")
project(":transliterationkit-android").projectDir = file("android")
