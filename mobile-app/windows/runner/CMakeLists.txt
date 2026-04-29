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
# Drives APP_ENV from the SPAMFILTER_APP_ENV environment variable seen by
# CMake at configure time (set by build-windows.ps1 before invoking
# `flutter build windows`). Defaults to "dev" if unset.
if(DEFINED ENV{SPAMFILTER_APP_ENV})
  set(SPAMFILTER_APP_ENV "$ENV{SPAMFILTER_APP_ENV}")
else()
  set(SPAMFILTER_APP_ENV "dev")
endif()
message(STATUS "Sprint 37 F52: SPAMFILTER_APP_ENV='${SPAMFILTER_APP_ENV}'")
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
