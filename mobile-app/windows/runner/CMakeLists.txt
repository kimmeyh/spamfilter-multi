cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Security hardening flags (SEC-23)
# /GS: Buffer security check (stack buffer overrun detection)
# /DYNAMICBASE: Address Space Layout Randomization (ASLR)
# /NXCOMPAT: Data Execution Prevention (DEP)
# /guard:cf: Control Flow Guard (CFG)
if(MSVC)
  target_compile_options(${BINARY_NAME} PRIVATE /GS /guard:cf)
  target_link_options(${BINARY_NAME} PRIVATE /DYNAMICBASE /NXCOMPAT /guard:cf)
endif()

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Sprint 37 F52 Phase 1: bake APP_ENV into the runner .exe at compile time
# so the window title is determined by the binary itself, not by a runtime
# command-line check. Required for direct-launch variants (Start-Process
# .exe with no args) and for Microsoft Store MSIX uploads where the
# launcher cannot pass --dart-define.
#
# F119-c (Sprint 49): DERIVE the value from the APP_ENV --dart-define first.
# The Sprint 37 design read ONLY the SPAMFILTER_APP_ENV environment variable
# (set by build-windows.ps1), but the Store MSIX path (`flutter pub run
# msix:create`) never set that env var -- so CMake fell back to "dev" and the
# native runner compiled the "[DEV]" window title into the 0.5.5 AND 0.5.6
# Store releases while the Dart side was correctly prod. The flutter tool
# records the build's dart-defines in ephemeral/generated_config.cmake
# (DART_DEFINES, entries individually base64-encoded). base64("APP_ENV=prod")
# is deterministically "QVBQX0VOVj1wcm9k" and base64("APP_ENV=dev") is
# "QVBQX0VOVj1kZXY=", so a bounded string match suffices -- no decode step.
# This makes the SINGLE --dart-define=APP_ENV=<env> flag (already injected by
# msix_config.windows_build_args for Store builds and by build-windows.ps1 for
# local builds) drive BOTH the Dart AppEnvironment AND this native define.
#
# PRECEDENCE: 1) APP_ENV dart-define recorded in generated_config.cmake;
# 2) SPAMFILTER_APP_ENV environment variable (build-windows.ps1 also exports
# it -- redundant but consistent; covers direct-CMake edge cases);
# 3) "dev" fallback (new-developer convenience for a bare
# `flutter build windows`).
set(_APP_ENV_FROM_DART_DEFINES "")
set(_GENERATED_CONFIG "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/ephemeral/generated_config.cmake")
if(EXISTS "${_GENERATED_CONFIG}")
  file(READ "${_GENERATED_CONFIG}" _GEN_CFG_TEXT)
  # Entries are comma-separated standalone base64 strings inside the
  # DART_DEFINES=... value; bound the match with the possible delimiters.
  if(_GEN_CFG_TEXT MATCHES "[=,\"]QVBQX0VOVj1wcm9k[,\"]")
    set(_APP_ENV_FROM_DART_DEFINES "prod")
  elseif(_GEN_CFG_TEXT MATCHES "[=,\"]QVBQX0VOVj1kZXY=[,\"]")
    set(_APP_ENV_FROM_DART_DEFINES "dev")
  endif()
endif()
if(NOT _APP_ENV_FROM_DART_DEFINES STREQUAL "")
  set(SPAMFILTER_APP_ENV "${_APP_ENV_FROM_DART_DEFINES}")
  message(STATUS "F119-c: SPAMFILTER_APP_ENV='${SPAMFILTER_APP_ENV}' (derived from APP_ENV dart-define)")
elseif(DEFINED ENV{SPAMFILTER_APP_ENV})
  set(SPAMFILTER_APP_ENV "$ENV{SPAMFILTER_APP_ENV}")
  message(STATUS "F119-c: SPAMFILTER_APP_ENV='${SPAMFILTER_APP_ENV}' (from environment variable; no APP_ENV dart-define found)")
else()
  set(SPAMFILTER_APP_ENV "dev")
  message(STATUS "F119-c: SPAMFILTER_APP_ENV='dev' (fallback; no dart-define, no env var)")
endif()
target_compile_definitions(${BINARY_NAME} PRIVATE "SPAMFILTER_APP_ENV=\"${SPAMFILTER_APP_ENV}\"")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
