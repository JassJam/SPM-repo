include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_download_file(URL "https://ftpmirror.gnu.org/gnu/libunistring/libunistring-1.4.2.tar.gz" DESTINATION
                  "${CMAKE_CURRENT_SOURCE_DIR}/libunistring-1.4.2.tar.gz")

spm_extract_archive(ARCHIVE "${CMAKE_CURRENT_SOURCE_DIR}/libunistring-1.4.2.tar.gz" DESTINATION "source" STRIP_COMPONENTS
                    1)

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

if(MSVC)
    list(APPEND _configure_opts "--disable-namespacing")
endif()

spm_autotools_configure(OPTIONS ${_configure_opts} DEPENDENCIES libiconv::libiconv)

if(MSVC AND NOT _shared)
    set(_lib_makefile "${CMAKE_CURRENT_SOURCE_DIR}/source/lib/Makefile")
    if(EXISTS "${_lib_makefile}")
        file(READ "${_lib_makefile}" _lib_makefile_contents)
        string(REGEX REPLACE "for f in .*libunistring_la.*; do "
                             "for f in ; do "
                             _patched_lib_makefile_contents "${_lib_makefile_contents}")
        if(NOT _patched_lib_makefile_contents STREQUAL _lib_makefile_contents)
            file(WRITE "${_lib_makefile}" "${_patched_lib_makefile_contents}")
        endif()
    endif()
endif()

spm_autotools_build()

spm_create_target(NAME libunistring DEPENDENCIES libiconv::libiconv)
