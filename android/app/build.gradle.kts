import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials, kept out of version control. See key.properties,
// which points at a keystore stored outside the repo.
//
// If the file is missing (a fresh clone, or a CI box without the secrets), the
// release build deliberately FAILS rather than silently falling back to the
// debug key. A debug-signed release is unshippable: Play rejects it, and a
// sideloaded build under a different key cannot update an existing install.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) keystorePropertiesFile.inputStream().use { load(it) }
}

// Fail loudly, and only when a release build is actually requested, so debug
// builds still work on a machine without the signing secrets.
if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "android/key.properties is missing -- cannot sign a release build.\n" +
                "It is intentionally not in version control. Restore it from your " +
                "password manager, pointing storeFile at your jobslip-release.p12 keystore."
        )
    }
    val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        throw GradleException("android/key.properties is missing entries: $missing")
    }
    val ks = file(keystoreProperties.getProperty("storeFile"))
    if (!ks.exists()) {
        throw GradleException("Keystore not found at ${ks.absolutePath} (from key.properties storeFile).")
    }
}

android {
    namespace = "com.digiflect.digiflect_quotes"
    // file_picker's dependency chain (flutter_plugin_android_lifecycle)
    // requires compiling against API 36+; flutter.compileSdkVersion lagged
    // behind that as of this Flutter version.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.digiflect.digiflect_quotes"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
            // minSdk is 24, and APK Signature Scheme v2 landed in API 24, so
            // every device that can install this app supports v2. v1 (JAR
            // signing) would only matter below API 24 and is left off.
            // v3 is enabled so the key can be rotated later if it ever leaks.
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
