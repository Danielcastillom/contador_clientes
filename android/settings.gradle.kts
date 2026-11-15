pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val propertiesFile = file("local.properties")
        if (propertiesFile.exists()) {
            properties.load(java.io.FileInputStream(propertiesFile))
        }
        val path = properties.getProperty("flutter.sdk")
        require(path != null) { "flutter.sdk not set in local.properties" }
        path
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

val flutterSdkPath = run {
    val properties = java.util.Properties()
    val propertiesFile = file("local.properties")
    if (propertiesFile.exists()) {
        properties.load(java.io.FileInputStream(propertiesFile))
    }
    properties.getProperty("flutter.sdk") ?: throw IllegalStateException("flutter.sdk not set in local.properties")
}

dependencyResolutionManagement {
    // Permitimos que los proyectos/plugins (como Firebase) declaren sus repositorios sin romper la compilación
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("$flutterSdkPath/bin/cache/artifacts/engine-maven")
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")