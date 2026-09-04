# GP-9 (Sprint 64, Issue #374): R8/ProGuard keep rules for release builds.
#
# Plugin-by-plugin audit performed against pubspec.yaml's resolved Android
# native/plugin dependencies before writing this file (no cargo-cult rules --
# every rule below exists because of a specific, verified gap):
#
#   flutter_appauth (12.0.2, wraps net.openid:appauth:0.11.1) -- AAR carries
#     no bundled consumer-rules.pro, but the plugin uses standard
#     MethodChannel + AuthorizationService API calls (no reflection). No
#     documented R8 issue for this usage shape. No rule added; the release
#     build's missing_rules.txt is the authoritative second check.
#   flutter_secure_storage (10.3.1), sqflite/sqflite_android (2.4.2+2),
#     google_sign_in/google_sign_in_android (7.2.7), connectivity_plus,
#     battery_plus, package_info_plus, url_launcher/url_launcher_android,
#     app_links, file_picker, webview_flutter/webview_flutter_android --
#     Flutter-team or Google-maintained plugins using standard MethodChannel
#     invocation; their AARs (Play Services Auth, AndroidX SQLite, etc.) ship
#     their own consumer-rules.pro applied automatically by AGP. No action
#     needed.
#   msal_auth (3.3.0) -- ships android/consumer-rules.pro (dontwarn rules for
#     its Gson/Tink/BouncyCastle/findbugs transitive deps), auto-applied by
#     AGP. NOT exercised at runtime today (outlook_adapter.dart is entirely
#     commented-out placeholder code, Outlook OAuth deferred per CLAUDE.md
#     Known Limitations) -- no additional keep rule added for a dead path.
#   flutter_local_notifications (17.2.4) -- its own bundled proguard-rules.pro
#     (found only under its example/ app, not auto-consumed) is entirely
#     Gson keep rules for a JSON adapter pattern this plugin does not use in
#     our integration (we call only initialize/show/AndroidNotificationDetails
#     per the pubspec dependency comment). No rule added.
#   workmanager / workmanager_android (0.10.7 / 0.10.6) -- ships NO
#     consumer-rules.pro. AndroidX WorkManager instantiates worker classes by
#     NAME via reflection (Class.forName) when a scheduled job fires, which is
#     exactly the shape R8 renaming breaks. Rule below is required.

# WorkManager instantiates dev.fluttercommunity.workmanager.BackgroundWorker
# by class name (stored in the WorkSpec) via reflection when a background
# scan job fires. Without this rule, R8 renames the class and a scheduled
# background scan fails at run time with a ClassNotFoundException that only
# appears once a job actually executes -- not at build or app-launch time.
-keep class dev.fluttercommunity.workmanager.** { *; }
