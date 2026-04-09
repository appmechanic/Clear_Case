plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.clearcase.clearcase"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Kotlin DSL requires '=' and isProperty syntax
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.clearcase.clearcase"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Kotlin DSL needs '='
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Kotlin DSL uses parentheses () for dependencies
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Note: If $kotlin_version isn't defined, you can use a hardcoded version or the standard library
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.22")
}

flutter {
    source = "../.."
}