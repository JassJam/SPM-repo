include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

option(SPM_LIBICONV_USE_SYSTEM_ON_LINUX "On Linux with gcc/clang, skip building and rely on glibc's built-in iconv" OFF)
option(SPM_LIBICONV_EXTRA_ENCODINGS "Enable --enable-extra-encodings (GNU libiconv only)" ON)
option(SPM_LIBICONV_RELOCATABLE "Enable --enable-relocatable (GNU libiconv only)" ON)

set(_shared "OFF")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "ON")
endif()

set(_use_system_iconv OFF)
if(SPM_LIBICONV_USE_SYSTEM_ON_LINUX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(_use_system_iconv ON)
endif()

if(_use_system_iconv)
    spm_create_dummy_target(NAME libiconv)

elseif(WIN32)
    spm_git_clone(URL https://github.com/win-iconv/win-iconv.git TAG v0.0.10)

    spm_cmake_configure(
        OPTIONS
        "-DBUILD_SHARED=${_shared}")

    spm_cmake_build()

    spm_create_target(NAME libiconv)

else()
    spm_download_file(
        URL "https://ftp.gnu.org/gnu/libiconv/libiconv-1.19.tar.gz"
        DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/libiconv-1.19.tar.gz")

    spm_extract_archive(
        ARCHIVE "${CMAKE_CURRENT_SOURCE_DIR}/libiconv-1.19.tar.gz"
        DESTINATION "source"
        STRIP_COMPONENTS 1)

    set(_configure_opts "--disable-dependency-tracking")

    if(_shared)
        list(APPEND _configure_opts "--enable-shared=yes" "--enable-static=no")
    else()
        list(APPEND _configure_opts "--enable-shared=no" "--enable-static=yes")
    endif()

    if(SPM_LIBICONV_EXTRA_ENCODINGS)
        list(APPEND _configure_opts "--enable-extra-encodings")
    endif()

    if(SPM_LIBICONV_RELOCATABLE)
        list(APPEND _configure_opts "--enable-relocatable")
    endif()

    if(SPM_BUILD_TYPE STREQUAL "Debug")
        list(APPEND _configure_opts "--enable-debug")
    endif()

    spm_autotools_configure(
        OPTIONS
        ${_configure_opts})

    spm_autotools_build()

    spm_create_target(NAME libiconv)
endif()
