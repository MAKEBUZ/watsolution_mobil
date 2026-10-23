plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseBuild = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val releaseStore = System.getenv("ANDROID_KEYSTORE_PATH")
val releaseApplicationId = System.getenv("ANDROID_APPLICATION_ID")
if (releaseBuild && (releaseStore.isNullOrBlank() || releaseApplicationId.isNullOrBlank() || releaseApplicationId.startsWith("com.example") ||
    System.getenv("ANDROID_KEYSTORE_PASSWORD").isNullOrBlank() || System.getenv("ANDROID_KEY_ALIAS").isNullOrBlank() || System.getenv("ANDROID_KEY_PASSWORD").isNullOrBlank())) {
    throw GradleException("Release requires the approved application ID and private signing configuration.")
}

android {
    namespace = "com.example.watsolution_mobil"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = releaseApplicationId ?: "com.example.watsolution_mobil"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!releaseStore.isNullOrBlank()) {
            create("production") {
                storeFile = file(releaseStore)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (!releaseStore.isNullOrBlank()) signingConfig = signingConfigs.getByName("production")
        }
    }
}

flutter {
    source = "../.."
}
