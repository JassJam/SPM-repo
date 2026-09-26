include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_download_file(URL "https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz" DESTINATION "libidn2-2.3.8.tar.gz")

spm_extract_archive(ARCHIVE "libidn2-2.3.8.tar.gz" DESTINATION source STRIP_COMPONENTS 1)

spm_requires(NAME libunistring VERSION 1.4.2)
spm_requires(NAME libiconv VERSION 1.19)

set(_idn2_deps libunistring::libunistring libiconv::libiconv)

set(_shared "no")
set(_static "yes")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "yes")
    set(_static "no")
endif()

set(_configure_opts "--disable-dependency-tracking")

if(_shared)
    list(APPEND _configure_opts "--enable-shared=yes" "--enable-static=no")
else()
    list(APPEND _configure_opts "--enable-shared=no" "--enable-static=yes")
endif()

if(SPM_LIBUNISTRING_PIC)
    list(APPEND _configure_opts "--with-pic")
endif()

spm_autotools_configure(
    OPTIONS
    ${_configure_opts}
    DEPENDENCIES
    ${_idn2_deps})

spm_autotools_build()

spm_create_target(NAME libidn2 DEPENDENCIES ${_idn2_deps})
