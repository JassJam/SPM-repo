include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
    URL https://github.com/Mbed-TLS/mbedtls.git
    TAG v3.6.2)

set(_shared "OFF")
set(_static "ON")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "ON")
    set(_static "OFF")
endif()

spm_cmake_configure(
    OPTIONS
    "-DUSE_SHARED_MBEDTLS_LIBRARY=${_shared}"
    "-DUSE_STATIC_MBEDTLS_LIBRARY=${_static}"
    -DENABLE_TESTING=OFF
    -DENABLE_PROGRAMS=OFF
    -DMBEDTLS_FATAL_WARNINGS=OFF)

spm_cmake_build()

if(${_static})
    if(MSVC)
        spm_create_target(
            NAME mbedtls
            STATIC_LIBS
            "mbedtls.lib"
            "mbedx509.lib"
            "mbedcrypto.lib")
    else()
        spm_create_target(
            NAME mbedtls
            STATIC_LIBS
            "libmbedtls.a"
            "libmbedx509.a"
            "libmbedcrypto.a")
    endif()
else()
    spm_create_target(NAME mbedtls)
endif()
