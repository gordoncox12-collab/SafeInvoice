import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
listOf(
    rootProject.file("../keystore.properties"),
    rootProject.file("keystore.properties"),
).firstOrNull { it.exists() }?.inputStream()?.use { keystoreProperties.load(it) }

fun signingValue(name: String): String? =
    System.getenv(name) ?: keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }

android {
    namespace = "app.safeinvoice"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.safeinvoice"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("en", "en-rZA")
    }

    signingConfigs {
        val storePath = signingValue("KEYSTORE_FILE") ?: signingValue("storeFile") ?: "play-upload.jks"
        val storeFileRef = file(storePath).takeIf { it.exists() }
            ?: rootProject.file(storePath).takeIf { it.exists() }
        if (storeFileRef != null) {
            create("release") {
                storeFile = storeFileRef
                storePassword = signingValue("KEYSTORE_PASSWORD") ?: signingValue("storePassword") ?: ""
                keyAlias = signingValue("KEY_ALIAS") ?: signingValue("keyAlias") ?: "upload"
                keyPassword = signingValue("KEY_PASSWORD") ?: signingValue("keyPassword") ?: ""
                // AGP disables v1 (JAR) signing by default when minSdk >= 24.
                // Many OEM / "APK Installer" apps still require v1 + v2.
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
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
