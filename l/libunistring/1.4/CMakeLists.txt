include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_download_file(URL "https://ftpmirror.gnu.org/gnu/libunistring/libunistring-1.4.tar.gz" DESTINATION
                  "${CMAKE_CURRENT_SOURCE_DIR}/libunistring-1.4.tar.gz")

spm_extract_archive(ARCHIVE "${CMAKE_CURRENT_SOURCE_DIR}/libunistring-1.4.tar.gz" DESTINATION "source" STRIP_COMPONENTS
                    1)

spm_apply_patch(
    PATCHES
        patches/undefines.patch
)

option(SPM_LIBUNISTRING_PIC "Build libunistring with -fPIC" ON)

spm_requires(NAME libiconv VERSION 1.19)

set(_shared "OFF")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "ON")
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

list(APPEND _configure_opts "CFLAGS=-g -O2 -std=gnu17")

spm_autotools_configure(OPTIONS ${_configure_opts} DEPENDENCIES libiconv::libiconv)

spm_autotools_build()

spm_create_target(NAME libunistring DEPENDENCIES libiconv::libiconv)
