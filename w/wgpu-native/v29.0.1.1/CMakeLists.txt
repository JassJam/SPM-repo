include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

if(CMAKE_BUILD_TYPE AND CMAKE_BUILD_TYPE STREQUAL "Release")
    set(_build_type "release")
else()
    set(_build_type "debug")
endif()

set(_base_url "https://github.com/gfx-rs/wgpu-native/releases/download/v29.0.1.1")
set(_platform "")

if(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(AMD64|x86_64)$")
    if(CMAKE_SIZEOF_VOID_P EQUAL 4)
        set(_platform wgpu-windows-i686-msvc)
    elseif(MSVC)
        set(_platform wgpu-windows-x86_64-msvc)
    else()
        set(_platform wgpu-windows-x86_64-gnu)
    endif()

elseif(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86|X86|i[3-6]86)$")
    set(_platform wgpu-windows-i686-msvc)

elseif(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(ARM64|aarch64)$")
    set(_platform wgpu-windows-aarch64-msvc)

elseif(ANDROID AND ANDROID_ABI STREQUAL "armeabi-v7a")
    set(_platform wgpu-android-armv7)

elseif(ANDROID AND ANDROID_ABI STREQUAL "arm64-v8a")
    set(_platform wgpu-android-aarch64)

elseif(ANDROID AND ANDROID_ABI STREQUAL "x86")
    set(_platform wgpu-android-i686)

elseif(ANDROID AND ANDROID_ABI STREQUAL "x86_64")
    set(_platform wgpu-android-x86_64)

elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
    set(_platform wgpu-linux-x86_64)

elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
    set(_platform wgpu-linux-aarch64)

elseif(APPLE AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
    set(_platform wgpu-macos-x86_64)

elseif(APPLE AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
    set(_platform wgpu-macos-aarch64)

endif()

if(NOT _platform)
    message(FATAL_ERROR "wgpu-native: unsupported platform/architecture combination")
endif()

set(_wgpu_sha256_wgpu-windows-x86_64-msvc_debug    479b5d777c72d4334c0b7dd2d5391e4b03e5813b6394c39e17f989ec802b7fd7)
set(_wgpu_sha256_wgpu-windows-x86_64-msvc_release  7e67d7445c42aeb85e30f88930fd8d7d83ee769e3390aeb1ada75ebf3cf78132)
set(_wgpu_sha256_wgpu-windows-x86_64-gnu_debug     13dee9513a3bb6a8cf731be34cda5d27eb1d40f6a5a5bb80664a649d853165f1)
set(_wgpu_sha256_wgpu-windows-x86_64-gnu_release   d471e3614733c1d4ddd61bfd19868356477d0d37bf531bf8c6cb64a7f579bd2a)
set(_wgpu_sha256_wgpu-windows-i686-msvc_debug      39ef1d4c5cec3cc2962d92ce0581a937ce9ba375a5c81524e7b53c08427133e9)
set(_wgpu_sha256_wgpu-windows-i686-msvc_release    ad59d4eadfcfe667999a37e096cc551ecf3f56c387b5a7fd5f61baebf105f54a)
set(_wgpu_sha256_wgpu-windows-aarch64-msvc_debug   5e82bef88491df14770e9837e0801d8af5e1044ed498cef55a71558ce8012971)
set(_wgpu_sha256_wgpu-windows-aarch64-msvc_release 4a876421a8c1e5fe72f849b3722214280fe485cb1c56f77f8b0c82414be5b29f)
set(_wgpu_sha256_wgpu-android-armv7_debug          d06bb39c43a5256d9146b2010cf591d0a48ba1562f6dd6d559c7e282d9adba2f)
set(_wgpu_sha256_wgpu-android-armv7_release        f9d76c77b3fda3f7121476884eb16ec067f7dada83276298a3cc8bf6a8403d60)
set(_wgpu_sha256_wgpu-android-aarch64_debug        925bbd0097f891b85b69ec6f9755072e362d2f7ed2c3668fe2a048f6858f2a39)
set(_wgpu_sha256_wgpu-android-aarch64_release      721741f1b05a20c1738166bedf7a5efb2ba4b382da689526d3fc33de22bdd573)
set(_wgpu_sha256_wgpu-android-i686_debug           f072125735c66ce4b84c295920dd5dd1758b7fb790c7dd6bc1d5bbd6fb03cdf9)
set(_wgpu_sha256_wgpu-android-i686_release         593b94875bc4fcc1506ea0b6714dd12b96b7c852921caa63f45eb61517793312)
set(_wgpu_sha256_wgpu-android-x86_64_debug         c54bef3de4eb6fea037604599578f77306e655d7c71c36d9f4da0c0f141e8663)
set(_wgpu_sha256_wgpu-android-x86_64_release       ef16fc0644bf0e308a39ac4516742da8e22d8c201d3a542cc5baf533d272c491)
set(_wgpu_sha256_wgpu-linux-x86_64_debug           befd2d5316e4008755b99056a6b330e727832e5813a21c5a8a66359f8369a300)
set(_wgpu_sha256_wgpu-linux-x86_64_release         95a4d90c071005a98d03eab348beaa6b07e16eb00d1dcdb9f8348f75eb97ec5a)
set(_wgpu_sha256_wgpu-linux-aarch64_debug          a611d4b8f55addbdd125ebcb424fda7f29749f14d440242ab5f3102b79a196b7)
set(_wgpu_sha256_wgpu-linux-aarch64_release        015fcdf1dbae82e614a783cc38017e5399ae0927a889fe9b69c9b664bc61b47a)
set(_wgpu_sha256_wgpu-macos-x86_64_debug           837d985e26c09db572d8b8a29cfe04b1c344977b92f6bf26843117483f584808)
set(_wgpu_sha256_wgpu-macos-x86_64_release         8e2f7378548ddd0e2cf21e7d864dda46e953f0af724855a33778b85ead206d41)
set(_wgpu_sha256_wgpu-macos-aarch64_debug          a5db38f501fcc8cd8e4e5a122bb36dfa6849dd0a3c65b658af8bf1d45a765379)
set(_wgpu_sha256_wgpu-macos-aarch64_release        a5797a37b1adf720bcd5dcffb291edbbd5b7b14be0a3874c28e6393a655a7a3e)

set(_hash_var "_wgpu_sha256_${_platform}_${_build_type}")
if(NOT DEFINED ${_hash_var})
    message(FATAL_ERROR "wgpu-native: no known sha256 for ${_platform} (${_build_type})")
endif()
set(_hash "${${_hash_var}}")

spm_download_file(
    URL "${_base_url}/${_platform}-${_build_type}.zip"
    EXPECTED_HASH SHA256=${_hash}
    DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/downloads/${_platform}-${_build_type}.zip"
)

spm_extract_archive(
    ARCHIVE "${CMAKE_CURRENT_SOURCE_DIR}/downloads/${_platform}-${_build_type}.zip"
    DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/install"
    DELETE_ARCHIVE
)

spm_create_target(
    NAME wgpu-native
)
