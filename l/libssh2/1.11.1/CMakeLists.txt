include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(URL https://github.com/libssh2/libssh2.git TAG libssh2-1.11.1)

spm_requires(NAME mbedtls VERSION 3.6.2)
spm_requires(NAME zlib VERSION 1.3.2)

set(_shared "OFF")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "ON")
endif()

spm_cmake_configure(
    OPTIONS
    "-DBUILD_SHARED_LIBS=${_shared}"
    -DCRYPTO_BACKEND=mbedTLS
    -DENABLE_ZLIB_COMPRESSION=ON
    -DBUILD_TESTING=OFF
    -DBUILD_EXAMPLES=OFF
    DEPENDENCIES
    zlib::zlib
    mbedtls::mbedtls)

spm_cmake_build()

spm_create_target(NAME libssh2 DEPENDENCIES zlib::zlib mbedtls::mbedtls)
