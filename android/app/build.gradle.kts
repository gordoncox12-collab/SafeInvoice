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
        minSdk = flutter.minSdkVersion
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

fun resignApkForOemInstallers(apk: File) {
    if (!apk.exists()) return
    val storePath = signingValue("KEYSTORE_FILE") ?: signingValue("storeFile") ?: "play-upload.jks"
    val storeFileRef = file(storePath).takeIf { it.exists() } ?: rootProject.file(storePath)
    val storePassword = signingValue("KEYSTORE_PASSWORD") ?: signingValue("storePassword") ?: return
    val keyAlias = signingValue("KEY_ALIAS") ?: signingValue("keyAlias") ?: "upload"
    val keyPassword = signingValue("KEY_PASSWORD") ?: signingValue("keyPassword") ?: storePassword
    if (!storeFileRef.exists()) return
    val script = rootProject.file("../scripts/sign_sideload_apk.py").takeIf { it.exists() }
        ?: rootProject.file("scripts/sign_sideload_apk.py")
    if (!script.exists()) error("Missing ${script.absolutePath}")
    val tmpOut = File(apk.parentFile, "${apk.nameWithoutExtension}-sideload.apk")
    val proc = ProcessBuilder(
        "python3",
        script.absolutePath,
        "--in", apk.absolutePath,
        "--out", tmpOut.absolutePath,
        "--ks", storeFileRef.absolutePath,
        "--ks-pass", storePassword,
        "--key-alias", keyAlias,
        "--key-pass", keyPassword,
    ).inheritIO().start()
    val code = proc.waitFor()
    if (code != 0) {
        error("sign_sideload_apk.py failed for ${apk.name} (exit $code)")
    }
    tmpOut.copyTo(apk, overwrite = true)
    tmpOut.delete()
    logger.lifecycle("Sideload-signed ${apk.name} with APK Signature Scheme v1 + v2")
}

afterEvaluate {
    extensions.findByType(com.android.build.api.dsl.ApplicationExtension::class.java)
        ?.defaultConfig
        ?.apply { minSdk = 23 }
    listOf("packageRelease", "assembleRelease").forEach { taskName ->
        tasks.findByName(taskName)?.doLast {
            listOf(
                layout.buildDirectory.file("outputs/apk/release/app-release.apk").get().asFile,
                layout.buildDirectory.file("outputs/flutter-apk/app-release.apk").get().asFile,
                rootProject.layout.buildDirectory.file("app/outputs/apk/release/app-release.apk").get().asFile,
                rootProject.layout.buildDirectory.file("app/outputs/flutter-apk/app-release.apk").get().asFile,
            ).distinctBy { it.absolutePath }.forEach { apk ->
                if (apk.exists()) resignApkForOemInstallers(apk)
            }
        }
    }
}
