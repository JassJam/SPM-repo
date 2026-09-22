include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
    URL https://github.com/curl/curl.git
    TAG curl-8_22_0)

option(CURL_USE_OPENSSL "Enable OpenSSL for SSL/TLS in curl" ON)
option(CURL_USE_MBEDTLS "Enable mbedTLS for SSL/TLS in curl" OFF)
option(ENABLE_ARES "Enable c-ares (async DNS) support in curl" ON)
option(CURL_USE_LIBSSH2 "Enable libssh2 (SFTP/SCP) support in curl" ON)
option(USE_NGHTTP2 "Enable HTTP/2 via nghttp2 in curl" ON)
option(CURL_ZLIB "Enable zlib (content decoding) in curl" ON)
option(CURL_ZSTD "Enable zstd (content decoding) in curl" ON)
option(CURL_BROTLI "Enable brotli (content decoding) in curl" ON)
option(USE_LIBIDN2 "Enable IDN support via libidn2 in curl" ON)
option(CURL_USE_LIBPSL "Enable libpsl (cookie domain checks) in curl" ON)
option(SPM_CURL_WITH_LDAP "Pull in openldap and let curl's own LDAP autodetection see it (non-Windows only)" OFF)

set(_curl_deps "")

if(CURL_USE_OPENSSL)
    spm_requires(NAME openssl VERSION 4.0.2)
    list(APPEND _curl_deps openssl::openssl)
endif()

if(CURL_USE_MBEDTLS)
    spm_requires(NAME mbedtls VERSION 3.6.2)
    list(APPEND _curl_deps mbedtls::mbedtls)
endif()

if(CURL_ZLIB)
    spm_requires(NAME zlib VERSION 1.3.2)
    list(APPEND _curl_deps zlib::zlib)
endif()

if(ENABLE_ARES)
    spm_requires(NAME cares VERSION 1.34.8)
    list(APPEND _curl_deps cares::cares)
endif()

if(CURL_USE_LIBSSH2)
    spm_requires(NAME libssh2 VERSION 1.11.1)
    list(APPEND _curl_deps libssh2::libssh2)
endif()

if(USE_NGHTTP2)
    spm_requires(NAME nghttp2 VERSION 1.70.0)
    list(APPEND _curl_deps nghttp2::nghttp2)
endif()

if(CURL_ZSTD)
    spm_requires(NAME zstd VERSION 1.5.7)
    list(APPEND _curl_deps zstd::zstd)
endif()

if(CURL_BROTLI)
    spm_requires(NAME brotli VERSION 1.2.0)
    list(APPEND _curl_deps brotli::brotli)
endif()

if(USE_LIBIDN2)
    spm_requires(NAME libidn2 VERSION 2.3.8)
    list(APPEND _curl_deps libidn2::libidn2)
endif()

if(CURL_USE_LIBPSL)
    spm_requires(NAME libpsl VERSION 0.21.0)
    list(APPEND _curl_deps libpsl::libpsl)
endif()

if(SPM_CURL_WITH_LDAP)
    if(WIN32)
        spm_log_fatal("SPM_CURL_WITH_LDAP is ON, but the openldap recipe has no Windows path (it requires a POSIX shell)")
    endif()
    spm_requires(NAME openldap VERSION 2.7.1)
    list(APPEND _curl_deps openldap::openldap)
endif()

set(_shared "OFF")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "ON")
endif()

spm_cmake_configure(
    OPTIONS
    "-DBUILD_SHARED_LIBS=${_shared}"
    -DBUILD_CURL_EXE=OFF
    -DBUILD_TESTING=OFF
    -DBUILD_LIBCURL_DOCS=OFF
    "-DCURL_USE_OPENSSL=${CURL_USE_OPENSSL}"
    "-DCURL_USE_MBEDTLS=${CURL_USE_MBEDTLS}"
    "-DENABLE_ARES=${ENABLE_ARES}"
    "-DCURL_USE_LIBSSH2=${CURL_USE_LIBSSH2}"
    "-DUSE_NGHTTP2=${USE_NGHTTP2}"
    "-DCURL_ZLIB=${CURL_ZLIB}"
    "-DCURL_ZSTD=${CURL_ZSTD}"
    "-DCURL_BROTLI=${CURL_BROTLI}"
    "-DUSE_LIBIDN2=${USE_LIBIDN2}"
    "-DCURL_USE_LIBPSL=${CURL_USE_LIBPSL}"
    DEPENDENCIES
    ${_curl_deps})

spm_cmake_build()

spm_create_target(NAME libcurl OUT_TARGET_NAME _curl_target)

if(WIN32)
    target_link_libraries(${_curl_target} INTERFACE ws2_32 crypt32 advapi32)
endif()
