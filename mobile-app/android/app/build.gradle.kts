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

        // SEC-9 (Sprint 64): flutter_appauth redirect scheme (reversed Android
        // OAuth client ID), sourced from a gradle property instead of a
        // hardcoded literal. build-with-secrets.ps1 supplies
        // -PandroidGmailClientId=<id> per -Env, reading the SAME
        // ANDROID_GMAIL_CLIENT_ID key from secrets.*.json that the Dart side
        // reads via --dart-define (single source of truth, both sides in
        // lockstep). Loud-fail policy (F119 lesson, adapted for CI): a
        // RELEASE build with no value fails the build outright -- a signed
        // release with an empty/placeholder redirect scheme cannot sign in
        // and must never ship silently. A DEBUG build (including the CI
        // Android-build-verification job, which passes no client-id property
        // per the F127 decision) logs a loud warning and falls back to an
        // OBVIOUSLY-FAKE placeholder so the compile still succeeds -- CI
        // never runs the app, so the fallback only needs to be build-shaped,
        // never a real (even if non-secret) credential. This keeps the real
        // id fragment out of gradle entirely (test/policy/
        // android_client_id_test.dart pins the source file, not just the
        // resolved manifest scheme).
        val androidGmailClientId = (project.findProperty("androidGmailClientId") as String?)
            ?.takeIf { it.isNotBlank() }
        val fallbackClientId = "000000000000-debugbuildplaceholderfallback"
        val resolvedClientId = if (androidGmailClientId != null) {
            androidGmailClientId
        } else {
            val isReleaseBuild = gradle.startParameter.taskNames.any {
                it.contains("Release", ignoreCase = true)
            }
            if (isReleaseBuild) {
                throw GradleException(
                    "SEC-9: androidGmailClientId gradle property is missing for a " +
                    "RELEASE build. Build with " +
                    "-PandroidGmailClientId=<id> (build-with-secrets.ps1 supplies " +
                    "this from secrets.*.json's ANDROID_GMAIL_CLIENT_ID key). " +
                    "A release build must never ship with an empty OAuth redirect " +
                    "scheme (F119 lesson)."
                )
            }
            logger.warn(
                "SEC-9 WARNING: androidGmailClientId gradle property not set; " +
                "falling back to a placeholder value for this DEBUG build only " +
                "(Gmail sign-in will NOT work with this build). Pass " +
                "-PandroidGmailClientId=<id> to override. This is expected in " +
                "CI (F127 decision) but NOT for a real device build that needs " +
                "working Gmail sign-in."
            )
            fallbackClientId
        }
        // secrets.*.json's ANDROID_GMAIL_CLIENT_ID carries the FULL OAuth
        // client id (e.g. "<prefix>.apps.googleusercontent.com"), matching
        // the Google Cloud Console copy-paste format and the Dart-side
        // dart-define value. The redirect scheme needs only the id prefix
        // (before the first dot) -- mirrors the Dart _mobileRedirectUri
        // getter's `.split('.').first`.
        val schemeIdPrefix = resolvedClientId.substringBefore(".")
        manifestPlaceholders["appAuthRedirectScheme"] = "com.googleusercontent.apps.$schemeIdPrefix"
    }

    // F94 (Sprint 63): dev/prod flavors mirroring the Windows ADR-0035 split.
    // The applicationId split is the DECLARED ADR-0042 platform exception:
    // Android side-by-side install requires distinct OS-level identity, which
    // Windows achieves with mutex + data-dir suffix alone. Pass
    // --dart-define=APP_ENV in LOCKSTEP with --flavor (build-with-secrets.ps1
    // -Env does both) so AppEnvironment/AppPaths agree with the installed
    // package. The launcher label carries the same [DEV] suffix as the
    // Windows window title.
    //
    // GOOGLE SIGN-IN STATUS: the PROD flavor keeps today's registered
    // package (com.myemailspamfilter) and working sign-in. The DEV flavor's
    // suffixed package builds against a committed structurally-valid STUB
    // google-services config (android/ci/google-services.dev-stub.json,
    // copied to src/dev/ by the build script -- same F158 pattern CI uses);
    // dev-flavor sign-in activates when Harold's four console registrations
    // land (Firebase SHA-1 x2 + GCP OAuth client x2, F94 prerequisites).
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabelSuffix"] = " [DEV]"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appLabelSuffix"] = ""
        }
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
    // GP-12 (Sprint 63): firebase-bom + firebase-analytics REMOVED per
    // ADR-0030 ("zero telemetry") / ADR-0033 (Accepted 2026-02-15). Nothing
    // else consumed the BOM (verified at planning: zero Dart-side Firebase
    // usage; pubspec has no firebase package). The google-services PLUGIN and
    // google-services.json stay -- Google Sign-In requires them (ADR-0030
    // implementation notes; do not remove them with any future cleanup).

    // Core library desugaring for Java 8+ compatibility (required by flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
