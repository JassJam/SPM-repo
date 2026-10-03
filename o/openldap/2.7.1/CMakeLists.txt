include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
    URL https://github.com/openldap/openldap.git
    TAG OPENLDAP_REL_ENG_2_7_1)

set(_shared "no")
set(_static "yes")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "yes")
    set(_static "no")
endif()

spm_requires(NAME openssl VERSION 4.0.2)

spm_autotools_configure(
    OPTIONS
    "--enable-shared=${_shared}"
    "--enable-static=${_static}"
    --disable-slapd
    --disable-backends
    --without-cyrus-sasl
    --with-tls=openssl
    DEPENDENCIES
    openssl::openssl)

spm_autotools_build()

spm_create_target(NAME openldap DEPENDENCIES openssl::openssl)
