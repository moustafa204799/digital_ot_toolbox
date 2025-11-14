pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // تم التحديث إلى 8.12.1 لدعم share_plus
    id("com.android.application") version "8.12.1" apply false
    // تم التحديث إلى 2.2.0 لدعم share_plus
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
}

include(":app")