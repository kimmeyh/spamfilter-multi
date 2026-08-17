plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin for Firebase configuration
    id("com.google.gms.google-services")
}

android {
    namespace = "com.myemailspamfilter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring for Java 8+ features (required by flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.myemailspamfilter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // F108 (Sprint 44): flutter_secure_storage 10 requires Android API 23+.
        // F157 (Sprint 60): adopted the Flutter gradle migrator's tracking form
        // (it kept rewriting a literal pin on every `flutter build apk`), but
        // wrapped in maxOf so the F108 floor stays EXPLICIT in code rather than
        // depending on Flutter's default never dropping below 23. Current
        // toolchain resolves flutter.minSdkVersion = 24, so 24 is the effective
        // floor today; it rises automatically with Flutter.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // flutter_appauth redirect scheme (reversed Android OAuth client ID)
        manifestPlaceholders["appAuthRedirectScheme"] = "com.googleusercontent.apps.577022808534-0ejdbmoouklgtucjo3tooovn2pr01ga2"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Import the Firebase Bill of Materials for consistent versions
    implementation(platform("com.google.firebase:firebase-bom:34.7.0"))
    // Example Firebase SDK (analytics); add others as needed
    implementation("com.google.firebase:firebase-analytics")

    // Core library desugaring for Java 8+ compatibility (required by flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
