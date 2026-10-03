include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

if(WIN32)
    find_program(PERL_EXECUTABLE NAMES perl PATHS "C:/Strawberry/perl/bin" "C:/Strawberry/c/bin" NO_DEFAULT_PATH)
endif()
if(NOT PERL_EXECUTABLE)
    find_program(PERL_EXECUTABLE NAMES perl)
endif()
if(NOT PERL_EXECUTABLE)
    spm_log_fatal("openssl recipe requires perl on PATH")
endif()

spm_git_clone(
    URL https://github.com/openssl/openssl.git
    TAG openssl-4.0.2)

set(_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/source")
set(_install_dir "${CMAKE_CURRENT_SOURCE_DIR}/install")

set(_want_shared OFF)
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_want_shared ON)
endif()
if(_want_shared)
    set(_shared_configure_flag "")
else()
    set(_shared_configure_flag "no-shared")
endif()

if(MSVC)
    if(NOT DEFINED ENV{VSINSTALLDIR})
        spm_log_fatal(
            "openssl recipe needs an already-activated MSVC dev environment on Windows (VSINSTALLDIR unset); "
            "run this from a Developer Command Prompt or via ilammy/msvc-dev-cmd in CI")
    endif()
    find_program(NMAKE_EXECUTABLE NAMES nmake)
    if(NOT NMAKE_EXECUTABLE)
        spm_log_fatal("openssl recipe requires nmake on PATH")
    endif()

    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(_target "VC-WIN64A")
    else()
        set(_target "VC-WIN32")
    endif()

    set(_make_cmd "${NMAKE_EXECUTABLE}")
else()
    set(_target "")
    find_program(MAKE_EXECUTABLE NAMES make)
    if(NOT MAKE_EXECUTABLE)
        spm_log_fatal("openssl recipe requires make on PATH")
    endif()
    set(_make_cmd "${MAKE_EXECUTABLE}")
endif()

string(SHA256 _stamp_key "${_source_dir}|${_install_dir}|${_target}|${_want_shared}")
set(_stamp_file "${_source_dir}/.spm-openssl-built-${_stamp_key}")
set(_stamped FALSE)
if(NOT SPM_FORCE_REBUILD)
    spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR _stamped)
    if(_stamped)
        spm_log_debug("openssl configure+build already done for these inputs, skipping")
    endif()
endif()

if(NOT _stamped OR SPM_FORCE_REBUILD)
    spm_execute_process(
        COMMAND
        ${PERL_EXECUTABLE}
        Configure
        ${_target}
        "--prefix=${_install_dir}"
        "--openssldir=${_install_dir}/ssl"
        "--libdir=lib"
        ${_shared_configure_flag}
        no-tests
        WORKING_DIRECTORY
        "${_source_dir}"
        RESULT_VARIABLE
        _cfg_result
        OUTPUT_VARIABLE
        _cfg_output
        ERROR_VARIABLE
        _cfg_output)
    if(NOT _cfg_result EQUAL 0)
        spm_log_fatal("Configure failed:\n${_cfg_output}")
    endif()

    spm_execute_process(
        COMMAND
        ${_make_cmd}
        -j
        ${SPM_PARALLEL_JOBS}
        WORKING_DIRECTORY
        "${_source_dir}"
        RESULT_VARIABLE
        _build_result
        OUTPUT_VARIABLE
        _build_output
        ERROR_VARIABLE
        _build_output)
    if(NOT _build_result EQUAL 0)
        spm_log_fatal("Build failed:\n${_build_output}")
    endif()

    spm_execute_process(
        COMMAND
        ${_make_cmd}
        install_sw
        WORKING_DIRECTORY
        "${_source_dir}"
        RESULT_VARIABLE
        _install_result
        OUTPUT_VARIABLE
        _install_output
        ERROR_VARIABLE
        _install_output)
    if(NOT _install_result EQUAL 0)
        spm_log_fatal("Install failed:\n${_install_output}")
    endif()

    foreach(_plugin_dir engines-3 ossl-modules)
        if(IS_DIRECTORY "${_install_dir}/lib/${_plugin_dir}")
            file(MAKE_DIRECTORY "${_install_dir}/ossl-plugins")
            file(RENAME "${_install_dir}/lib/${_plugin_dir}" "${_install_dir}/ossl-plugins/${_plugin_dir}")
        endif()
    endforeach()

    spm_write_stamp_file(FILE "${_stamp_file}")
endif()

if(_want_shared)
    spm_create_target(NAME openssl OUT_TARGET_NAME _ssl_target)
elseif(MSVC)
    spm_create_target(NAME openssl OUT_TARGET_NAME _ssl_target STATIC_LIBS "libssl.lib" "libcrypto.lib")
else()
    spm_create_target(NAME openssl OUT_TARGET_NAME _ssl_target STATIC_LIBS "libssl.a" "libcrypto.a")
endif()

if(WIN32)
    target_link_libraries(${_ssl_target} INTERFACE ws2_32 crypt32)
endif()
