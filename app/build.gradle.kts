import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun signingValue(name: String): String? =
    System.getenv(name) ?: keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }

android {
    namespace = "app.safeinvoice"
    compileSdk = 35

    defaultConfig {
        applicationId = "app.safeinvoice"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        resourceConfigurations += listOf("en", "en-rZA")
    }

    signingConfigs {
        val storePath = signingValue("KEYSTORE_FILE") ?: signingValue("storeFile")
        val storeFileRef = storePath?.let { rootProject.file(it) }
        if (storeFileRef != null && storeFileRef.exists()) {
            create("release") {
                storeFile = storeFileRef
                storePassword = signingValue("KEYSTORE_PASSWORD") ?: signingValue("storePassword") ?: ""
                keyAlias = signingValue("KEY_ALIAS") ?: signingValue("keyAlias") ?: "upload"
                keyPassword = signingValue("KEY_PASSWORD") ?: signingValue("keyPassword") ?: ""
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ""
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/LICENSE.md",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/NOTICE.md",
                "META-INF/INDEX.LIST",
                "META-INF/*.kotlin_module",
            )
            pickFirsts += setOf(
                "META-INF/services/javax.xml.stream.XMLInputFactory",
                "META-INF/services/javax.xml.stream.XMLOutputFactory",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring(libs.desugar.jdk.libs)

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    debugImplementation(libs.androidx.compose.ui.tooling)

    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.coil.compose)

    implementation(libs.poi)
    implementation(libs.poi.ooxml)

    testImplementation(libs.junit)
}
