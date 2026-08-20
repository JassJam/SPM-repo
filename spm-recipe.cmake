include_guard(GLOBAL)

cmake_minimum_required(VERSION 3.24)

set(SPM_PARALLEL_JOBS
    "4"
    CACHE STRING "Parallel build jobs used when building a recipe")

set(SPM_VERBOSE_OUTPUT
    ON
    CACHE BOOL "Verbose SPM logging")

set(SPM_IMPORT_NAME
    ""
    CACHE STRING "namespace of the target to be installed")

set(SPM_SKIP_TESTS
    OFF
    CACHE BOOL "Skip recipe test phase even if RUN_TESTS was requested (warn instead of fail)")

set(SPM_FORCE_REBUILD
    OFF
    CACHE BOOL "Ignore all cache hits and rebuild every requested package from scratch")

set(SPM_BUILD_TYPE
    ""
    CACHE STRING "Target build type")

set(SPM_BUILD_SHARED_LIBS
    ""
    CACHE STRING "Recipe library type")

#

find_program(GIT_EXECUTABLE NAMES git)

macro(_spm_requires_git)
    if(NOT GIT_EXECUTABLE)
        spm_log_fatal("no git executable was found")
    endif()
endmacro()

function(spm_log)
    if(SPM_VERBOSE_OUTPUT)
        string(REPLACE "\\" "\\\\" _msg "${ARGV}")
        message(STATUS "[SPM]: ${_msg}.")
    endif()
endfunction()

function(spm_log_fatal)
    string(REPLACE "\\" "\\\\" _spm_log_fatal_msg "${ARGV}")
    message(FATAL_ERROR "[SPM]: ${_spm_log_fatal_msg}.")
endfunction()

macro(spm_execute_process)
    spm_log("Executing ${ARGV}")
    execute_process(${ARGV})
endmacro()

#

# Checks/writes a stamp file, used to not repatch/do expensive operations
#
# spm_stamp_file(
#   [FILE .spm-stamped]
#   OUT_VAR <var> # sets tp true if the stamp already exists
# )
function(spm_stamp_file)
    set(oneValArgs FILE OUT_VAR)
    cmake_parse_arguments(B "" "${oneValArgs}" "" ${ARGN})

    if(NOT B_FILE)
        set(B_FILE "${CMAKE_CURRENT_SOURCE_DIR}/.spm-stamped")
    endif()

    if(B_OUT_VAR)
        if(EXISTS "${B_FILE}")
            set(${B_OUT_VAR}
                TRUE
                PARENT_SCOPE)
            spm_log("Stamp file ${B_FILE} exists, ignoring")
        else()
            set(${B_OUT_VAR}
                FALSE
                PARENT_SCOPE)
            get_filename_component(_stamp_dir "${B_FILE}" DIRECTORY)
            if(_stamp_dir AND NOT EXISTS "${_stamp_dir}")
                file(MAKE_DIRECTORY "${_stamp_dir}")
            endif()
            file(WRITE "${B_FILE}" "ok")
            spm_log("Stamped '${B_FILE}'")
        endif()
    endif()
endfunction()

# Declares that the current recipe depends on another package.
# Resolves and # builds it immediately (like spm_require_package),
#
# spm_requires(
#   NAME zip
#   VERSION 1.3.1
#   [IMPORT_NAME minizip]
#   [ ... any spm_require_package() arg: OPTIONS, GIT_URL, GIT_TAG, REGISTRY, FORCE, SHARED ... ]
# )
function(spm_requires)
    set(options FORCE SHARED)
    set(oneValArgs NAME VERSION IMPORT_NAME)
    cmake_parse_arguments(R "${options}" "${oneValArgs}" "" ${ARGN})

    if(NOT R_NAME)
        spm_log_fatal("spm_requires() requires a NAME")
    endif()

    if(NOT R_IMPORT_NAME)
        set(R_IMPORT_NAME "${R_NAME}")
    endif()
    set(_name "${R_IMPORT_NAME}::${R_NAME}")

    # Catch two recipes in the same tree wanting different versions of the same package.
    get_property(_required GLOBAL PROPERTY SPM_REQUIRED_PACKAGES)
    foreach(_entry ${_required})
        if(_entry MATCHES "^(.*)@(.*)$"
           AND CMAKE_MATCH_1 STREQUAL R_NAME
           AND NOT CMAKE_MATCH_2 STREQUAL R_VERSION)
            spm_log_fatal(
                "Version conflict for '${R_NAME}': already resolved at '${CMAKE_MATCH_2}', now requested at '${R_VERSION}'"
            )
        endif()
    endforeach()

    string(MAKE_C_IDENTIFIER "${R_NAME}_${R_VERSION}" _pkg_key)
    get_property(_dep_install_dir GLOBAL PROPERTY SPM_DEP_INSTALL_DIR_${_pkg_key})

    if(_dep_install_dir)
        spm_log("Dependency '${R_NAME}@${R_VERSION}' already built elsewhere, reusing")
    else()
        include("${CMAKE_CURRENT_SOURCE_DIR}/spm.cmake")
        spm_require_package(${ARGN} OUT_INSTALL_DIR _dep_install_dir)
        if(NOT _dep_install_dir)
            spm_log_fatal("spm_requires(NAME ${R_NAME}) produced no install dir (unsupported on this platform?)")
        endif()
        set_property(GLOBAL PROPERTY SPM_DEP_INSTALL_DIR_${_pkg_key} "${_dep_install_dir}")
        set_property(GLOBAL APPEND PROPERTY SPM_REQUIRED_PACKAGES "${R_NAME}@${R_VERSION}")
    endif()

    set_property(GLOBAL PROPERTY SPM_DEP_INSTALL_DIR_NAME_${_name} "${_dep_install_dir}")
    set_property(
        DIRECTORY
        APPEND
        PROPERTY SPM_RECIPE_DEPENDENCIES "${_name}")

    spm_log("Recipe now depends on '${_name}' (installed at ${_dep_install_dir})")
endfunction()

function(_spm_resolve_dependency_targets deps out_var)
    get_property(
        _declared
        DIRECTORY
        PROPERTY SPM_RECIPE_DEPENDENCIES)
    set(_resolved "")
    foreach(_dep ${deps})
        if(_dep MATCHES "^([^:]+)::(.+)$")
            set(_dep_ns "${CMAKE_MATCH_1}")
            set(_dep_target "${_dep}")
        else()
            set(_dep_ns "${_dep}")
            set(_dep_target "${_dep}::${_dep}")
        endif()
        if(NOT TARGET ${_dep_target})
            spm_log_fatal("DEPENDENCIES entry '${_dep}' resolves to '${_dep_target}', which is not a target")
        endif()
        list(APPEND _resolved "${_dep_target}")
    endforeach()
    set(${out_var}
        "${_resolved}"
        PARENT_SCOPE)
endfunction()

# Fetches from a git source
# spm_git_clone(
#   URL <url>
#   TAG <tag>
#   [DESTINATION source]
# )
function(spm_git_clone)
    _spm_requires_git()

    set(oneValArgs URL TAG DESTINATION)
    cmake_parse_arguments(B "" "${oneValArgs}" "" ${ARGN})

    if(NOT B_DESTINATION)
        set(B_DESTINATION source)
    endif()

    spm_stamp_file(FILE "${CMAKE_CURRENT_SOURCE_DIR}/.spm-gitclone-${B_DESTINATION}" OUT_VAR exists)
    if(exists)
        return()
    endif()

    set(_dest_file "${CMAKE_CURRENT_SOURCE_DIR}/${B_DESTINATION}")
    if(EXISTS "${_dest_file}")
        file(REMOVE_RECURSE "${_dest_file}")
    endif()
    file(MAKE_DIRECTORY "${_dest_file}")

    set(_clone_args "")
    if(NOT B_TAG)
        list(APPEND _clone_args --depth 1)
    endif()

    spm_log("Cloning ${B_URL}")
    spm_execute_process(
        COMMAND
        ${GIT_EXECUTABLE}
        clone
        ${_clone_args}
        "${B_URL}"
        "${_dest_file}"
        RESULT_VARIABLE
        _git_result
        OUTPUT_VARIABLE
        _git_output
        ERROR_VARIABLE
        _git_output)
    if(NOT _git_result EQUAL 0)
        file(REMOVE_RECURSE "${_dest_file}")
        spm_log_fatal("git clone failed for (${_URL}):\n${_git_output}")
    endif()

    if(B_TAG)
        spm_log("Checking out '${B_TAG}'")
        spm_execute_process(
            COMMAND
            ${GIT_EXECUTABLE}
            checkout
            "${B_TAG}"
            WORKING_DIRECTORY
            "${_dest_file}"
            RESULT_VARIABLE
            _checkout_result
            OUTPUT_VARIABLE
            _checkout_output
            ERROR_VARIABLE
            _checkout_output)

        if(NOT _checkout_result EQUAL 0)
            spm_execute_process(
                COMMAND
                ${GIT_EXECUTABLE}
                fetch
                --depth
                1
                origin
                "${B_TAG}"
                WORKING_DIRECTORY
                "${_dest_file}"
                RESULT_VARIABLE
                _fetch_result
                OUTPUT_VARIABLE
                _fetch_output
                ERROR_VARIABLE
                _fetch_output)

            if(_fetch_result EQUAL 0)
                spm_execute_process(
                    COMMAND
                    ${GIT_EXECUTABLE}
                    checkout
                    FETCH_HEAD
                    WORKING_DIRECTORY
                    "${_dest_file}"
                    RESULT_VARIABLE
                    _checkout_result
                    OUTPUT_VARIABLE
                    _checkout_output
                    ERROR_VARIABLE
                    _checkout_output)
            endif()

            if(NOT _checkout_result EQUAL 0)
                file(REMOVE_RECURSE "${_dest_file}")
                spm_log_fatal("Failed to check out '${B_TAG}':\n${_checkout_output}")
            endif()
        endif()

        spm_execute_process(
            COMMAND
            ${GIT_EXECUTABLE}
            submodule
            update
            --init
            --recursive
            --depth
            1
            WORKING_DIRECTORY
            "${_dest_file}"
            RESULT_VARIABLE
            _submod_result
            OUTPUT_VARIABLE
            _submod_output
            ERROR_VARIABLE
            _submod_output)
        if(NOT _submod_result EQUAL 0)
            spm_log_fatal("git submodule update failed:\n${_submod_output}")
        endif()
    endif()
endfunction()

# Downloads a file, with header/auth support, hash verification, and retry.
#
# spm_download_file(
#   URL <url>
#   DESTINATION <path>
#   [HEADERS "Header: value" ...]
#   [EXPECTED_HASH <ALGO>=<value>]
#   [TIMEOUT <seconds>]
#   [RETRIES <n>]
#   [FORCE]
# )
function(spm_download_file)
    set(options FORCE)
    set(oneValArgs URL DESTINATION EXPECTED_HASH TIMEOUT RETRIES)
    set(multiValArgs HEADERS)
    cmake_parse_arguments(B "${options}" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    if(B_UNPARSED_ARGUMENTS)
        spm_log_fatal("spm_download_file() got unrecognized arguments: ${B_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT B_URL)
        spm_log_fatal("spm_download_file() requires a URL")
    endif()
    if(NOT B_DESTINATION)
        spm_log_fatal("spm_download_file() requires a DESTINATION")
    endif()

    if(NOT IS_ABSOLUTE "${B_DESTINATION}")
        set(B_DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/${B_DESTINATION}")
    endif()

    if(NOT B_RETRIES)
        set(B_RETRIES 3)
    endif()

    # Stamp is keyed off URL + destination + expected hash, so changing any of
    # those forces a re-download even if a stale file is sitting at DESTINATION.
    string(SHA256 _stamp_key "${B_URL}|${B_DESTINATION}|${B_EXPECTED_HASH}")
    set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-download-${_stamp_key}")

    spm_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
    if(${exists} AND EXISTS "${B_DESTINATION}")
        return()
    endif()

    get_filename_component(_dest_dir "${B_DESTINATION}" DIRECTORY)
    if(_dest_dir AND NOT EXISTS "${_dest_dir}")
        file(MAKE_DIRECTORY "${_dest_dir}")
    endif()

    set(_download_args
        "${B_URL}" "${B_DESTINATION}"
        STATUS _status
        LOG _log
        TLS_VERIFY ON)

    if(B_TIMEOUT)
        list(APPEND _download_args TIMEOUT "${B_TIMEOUT}")
    endif()
    if(B_HEADERS)
        list(APPEND _download_args HTTPHEADER "${B_HEADERS}")
    endif()

    if(B_EXPECTED_HASH)
        list(APPEND _download_args EXPECTED_HASH "${B_EXPECTED_HASH}")
    endif()

    spm_log("Downloading '${B_URL}' to '${B_DESTINATION}'")

    set(_attempt 0)
    set(_ok FALSE)
    while(NOT _ok AND _attempt LESS B_RETRIES)
        math(EXPR _attempt "${_attempt} + 1")

        file(DOWNLOAD ${_download_args})

        list(GET _status 0 _status_code)
        list(GET _status 1 _status_msg)

        if(_status_code EQUAL 0)
            set(_ok TRUE)
        else()
            spm_log("Download attempt ${_attempt}/${B_RETRIES} failed (${_status_code}: ${_status_msg})")
            if(EXISTS "${B_DESTINATION}")
                file(REMOVE "${B_DESTINATION}")
            endif()
        endif()
    endwhile()

    if(NOT _ok)
        spm_log_fatal(
            "Failed to download '${B_URL}' after ${B_RETRIES} attempt(s): ${_status_msg}\nLog:\n${_log}"
        )
    endif()

    spm_stamp_file(FILE "${_stamp_file}")
    spm_log("Downloaded '${B_DESTINATION}' (${_attempt} attempt(s))")
endfunction()

# Extracts an archive via libarchive.
#
# spm_extract_archive(
#   ARCHIVE <path>
#   DESTINATION <path>
#   [STRIP_COMPONENTS <n>]
#   [DELETE_ARCHIVE]
# )
function(spm_extract_archive)
    set(options DELETE_ARCHIVE)
    set(oneValArgs ARCHIVE DESTINATION STRIP_COMPONENTS)
    cmake_parse_arguments(B "${options}" "${oneValArgs}" "" ${ARGN})

    if(B_UNPARSED_ARGUMENTS)
        spm_log_fatal("spm_extract_archive() got unrecognized arguments: ${B_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT B_ARCHIVE)
        spm_log_fatal("spm_extract_archive() requires ARCHIVE")
    endif()
    if(NOT B_DESTINATION)
        spm_log_fatal("spm_extract_archive() requires DESTINATION")
    endif()
    if(NOT B_STRIP_COMPONENTS)
        set(B_STRIP_COMPONENTS 0)
    endif()

    if(NOT IS_ABSOLUTE "${B_ARCHIVE}")
        set(B_ARCHIVE "${CMAKE_CURRENT_SOURCE_DIR}/${B_ARCHIVE}")
    endif()
    if(NOT IS_ABSOLUTE "${B_DESTINATION}")
        set(B_DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/${B_DESTINATION}")
    endif()

    if(NOT EXISTS "${B_ARCHIVE}")
        spm_log_fatal("spm_extract_archive(): archive '${B_ARCHIVE}' does not exist")
    endif()

    string(SHA256 _stamp_key "${B_ARCHIVE}|${B_DESTINATION}|${B_STRIP_COMPONENTS}")
    set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-extract-${_stamp_key}")

    spm_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
    if(${exists} AND EXISTS "${B_DESTINATION}")
        return()
    endif()

    if(EXISTS "${B_DESTINATION}")
        file(REMOVE_RECURSE "${B_DESTINATION}")
    endif()
    file(MAKE_DIRECTORY "${B_DESTINATION}")

    if(B_STRIP_COMPONENTS GREATER 0)
        # Extract to a scratch dir first, then peel off N path components
        # while moving everything into DESTINATION.
        set(_scratch_dir "${B_DESTINATION}.spm-extract-tmp")
        if(EXISTS "${_scratch_dir}")
            file(REMOVE_RECURSE "${_scratch_dir}")
        endif()
        file(MAKE_DIRECTORY "${_scratch_dir}")

        spm_log("Extracting '${B_ARCHIVE}' to '${_scratch_dir}' (will strip ${B_STRIP_COMPONENTS} component(s))")
        file(ARCHIVE_EXTRACT INPUT "${B_ARCHIVE}" DESTINATION "${_scratch_dir}")

        set(_src_dir "${_scratch_dir}")
        foreach(_i RANGE 1 ${B_STRIP_COMPONENTS})
            file(GLOB _children "${_src_dir}/*")
            list(LENGTH _children _n_children)
            if(NOT _n_children EQUAL 1 OR NOT IS_DIRECTORY "${_children}")
                spm_log_fatal(
                    "spm_extract_archive(): cannot strip ${B_STRIP_COMPONENTS} component(s), "
                    "'${_src_dir}' does not contain exactly one subdirectory at depth ${_i}"
                )
            endif()
            set(_src_dir "${_children}")
        endforeach()

        file(GLOB _final_children "${_src_dir}/*")
        foreach(_child ${_final_children})
            file(COPY "${_child}" DESTINATION "${B_DESTINATION}")
        endforeach()

        file(REMOVE_RECURSE "${_scratch_dir}")
    else()
        spm_log("Extracting '${B_ARCHIVE}' to '${B_DESTINATION}'")
        file(ARCHIVE_EXTRACT INPUT "${B_ARCHIVE}" DESTINATION "${B_DESTINATION}")
    endif()

    spm_stamp_file(FILE "${_stamp_file}")
    spm_log("Extracted '${B_ARCHIVE}' to '${B_DESTINATION}'")

    if(B_DELETE_ARCHIVE)
        file(REMOVE "${B_ARCHIVE}")
        spm_log("Deleted archive '${B_ARCHIVE}'")
    endif()
endfunction()

# Patches source
# spm_apply_patch(
#   PATCHES ...
#   [SOURCE_DIR source]
# )
function(spm_apply_patch)
    _spm_requires_git()

    set(oneValArgs SOURCE_DIR)
    set(multiValArgs PATCHES)
    cmake_parse_arguments(B "" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    if(NOT B_SOURCE_DIR)
        set(B_SOURCE_DIR source)
    endif()

    set(_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/${B_SOURCE_DIR}")
    foreach(_patch ${B_PATCHES})
        if(IS_ABSOLUTE "${_patch}")
            set(_patch_file "${_patch}")
        else()
            set(_patch_file "${CMAKE_CURRENT_SOURCE_DIR}/${_patch}")
        endif()

        string(SHA256 _hash "${_patch_file}")
        spm_stamp_file(FILE "${CMAKE_CURRENT_SOURCE_DIR}/.spm-patch-${_hash}" OUT_VAR exists)
        if(exists)
            continue()
        endif()

        spm_log("Applying patch '${_patch}'")
        spm_execute_process(
            COMMAND
            ${GIT_EXECUTABLE}
            apply
            --whitespace=fix
            "${_patch_file}"
            WORKING_DIRECTORY
            "${_source_dir}"
            RESULT_VARIABLE
            _patch_result
            OUTPUT_VARIABLE
            _patch_output
            ERROR_VARIABLE
            _patch_output)
        if(NOT _patch_result EQUAL 0)
            spm_log_fatal("Failed to apply patch '${_patch}':\n${_patch_output}")
        endif()
    endforeach()
endfunction()

# Configure a cmake target
# spm_cmake_configure(
#   [SOURCE_DIR source]
#   [BUILD_DIR build]
#   [INSTALL_DIR install]
#   [OPTIONS ...]
#   [DEPENDENCIES ...]
# )
function(spm_cmake_configure)
    _spm_requires_git()

    set(oneValArgs SOURCE_DIR BUILD_DIR INSTALL_DIR)
    set(multiValArgs OPTIONS DEPENDENCIES)
    cmake_parse_arguments(B "" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    if(NOT B_SOURCE_DIR)
        set(B_SOURCE_DIR source)
    endif()

    if(NOT B_BUILD_DIR)
        set(B_BUILD_DIR build)
    endif()

    if(NOT B_INSTALL_DIR)
        set(B_INSTALL_DIR install)
    endif()

    set(_dep_prefix_paths "")
    if(B_DEPENDENCIES)
        get_property(
            _declared
            DIRECTORY
            PROPERTY SPM_RECIPE_DEPENDENCIES)
        foreach(_dep ${B_DEPENDENCIES})
            if(NOT _dep IN_LIST _declared)
                spm_log_fatal("DEPENDENCIES entry '${_dep}' was not declared via spm_requires() in this recipe")
            endif()
            get_property(_dep_dir GLOBAL PROPERTY SPM_DEP_INSTALL_DIR_NAME_${_dep})
            if(NOT _dep_dir)
                spm_log_fatal("No install directory recorded for dependency '${_dep}'")
            endif()
            list(APPEND _dep_prefix_paths "${_dep_dir}")
        endforeach()
    endif()
    if(CMAKE_PREFIX_PATH)
        list(PREPEND _dep_prefix_paths ${CMAKE_PREFIX_PATH})
    endif()

    set(_prefix_path_arg "")
    if(_dep_prefix_paths)
        set(_prefix_cache_file "${CMAKE_CURRENT_SOURCE_DIR}/spm-prefix-path.cmake")
        file(WRITE "${_prefix_cache_file}" "set(CMAKE_PREFIX_PATH \"")
        set(_first TRUE)
        foreach(_p ${_dep_prefix_paths})
            if(NOT _first)
                file(APPEND "${_prefix_cache_file}" ";")
            endif()
            file(APPEND "${_prefix_cache_file}" "${_p}")
            set(_first FALSE)
        endforeach()
        file(APPEND "${_prefix_cache_file}" "\" CACHE STRING \"\" FORCE)\n")
        set(_prefix_path_arg -C "${_prefix_cache_file}")
    endif()

    set(_args "")
    list(APPEND _args "-DCMAKE_INSTALL_PREFIX=${B_INSTALL_DIR}")

    spm_execute_process(
        COMMAND
        ${CMAKE_COMMAND}
        -S
        ${B_SOURCE_DIR}
        -B
        ${B_BUILD_DIR}
        -G
        "${CMAKE_GENERATOR}"
        -C
        "spm-input.cmake"
        ${_args}
        ${_prefix_path_arg}
        ${B_OPTIONS}
        WORKING_DIRECTORY
        "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE
        _cfg_result
        OUTPUT_VARIABLE
        _cfg_output
        ERROR_VARIABLE
        _cfg_output)

    if(NOT _cfg_result EQUAL 0)
        spm_log_fatal("Configure failed:\n${_cfg_output}")
    else()
        spm_log("Configure succeeded:\n${_cfg_output}")
    endif()

endfunction()

# Build a configured cmake target
# spm_cmake_build(
#   [BUILD_DIR build]
# )
function(spm_cmake_build)
    _spm_requires_git()

    set(oneValArgs BUILD_DIR)
    cmake_parse_arguments(B "" "${oneValArgs}" "" ${ARGN})

    if(NOT B_BUILD_DIR)
        set(B_BUILD_DIR build)
    endif()

    set(_build_target_args)

    spm_execute_process(
        COMMAND
        ${CMAKE_COMMAND}
        --build
        ${B_BUILD_DIR}
        --config
        ${SPM_BUILD_TYPE}
        --parallel
        ${SPM_PARALLEL_JOBS}
        --target
        install
        WORKING_DIRECTORY
        "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE
        _build_result
        OUTPUT_VARIABLE
        _build_output
        ERROR_VARIABLE
        _build_output)
    if(NOT _build_result EQUAL 0)
        spm_log_fatal("Build failed target:\n${_build_output}")
    endif()
endfunction()

#
#

# Creates a target from a package install directory laid out as:
#   .
#   |_ include/
#   |_ bin/
#   |_ lib/
#   |_ extra/
#
# spm_create_target(
#   NAME <name>
#   [INSTALL_DIR <path>]
#   [OUT_TARGET_NAME <name>]
#   [EXTRA_DIRS <source>[::<destination>] ...]
#   [DEPENDENCIES <spm dep names>...]
#   [STATIC_LIBS <libs>...]
# )
function(spm_create_target)
    set(oneValArgs NAME INSTALL_DIR OUT_TARGET_NAME)
    set(multiValArgs EXTRA_DIRS DEPENDENCIES STATIC_LIBS)
    cmake_parse_arguments(B "" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    if(B_UNPARSED_ARGUMENTS)
        spm_log_fatal("spm_create_target(NAME ${B_NAME}) got unrecognized arguments: ${B_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT B_INSTALL_DIR)
        set(B_INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/install")
    endif()
    if(NOT B_NAME)
        spm_log_fatal("spm_create_target requires a name")
    endif()
    if(NOT SPM_IMPORT_NAME)
        spm_log_fatal("SPM_IMPORT_NAME is not set (spm_create_target must run inside an SPM recipe build)")
    endif()

    if(IS_DIRECTORY "${B_INSTALL_DIR}/include")
        set(_has_include TRUE)
    else()
        set(_has_include FALSE)
    endif()
    if(IS_DIRECTORY "${B_INSTALL_DIR}/lib")
        set(_has_lib TRUE)
    else()
        set(_has_lib FALSE)
    endif()
    if(IS_DIRECTORY "${B_INSTALL_DIR}/bin")
        set(_has_bin TRUE)
    else()
        set(_has_bin FALSE)
    endif()

    if(NOT _has_include
       AND NOT _has_lib
       AND NOT _has_bin)
        spm_log_fatal(
            "spm_create_target(NAME ${B_NAME}): '${B_INSTALL_DIR}' has none of include/, lib/, bin/, recipe didn't build/install anything"
        )
    endif()

    set(_target_name "_spm_${SPM_IMPORT_NAME}_${B_NAME}")
    if(TARGET ${_target_name})
        spm_log_fatal("Target '${_target_name}' already exists")
    endif()
    if(B_OUT_TARGET_NAME)
        set(${B_OUT_TARGET_NAME}
            ${_target_name}
            PARENT_SCOPE)
    endif()

    add_library(${_target_name} INTERFACE IMPORTED GLOBAL)
    add_library(${SPM_IMPORT_NAME}::${B_NAME} ALIAS ${_target_name})

    set(_link_libs "")

    if(_has_include)
        set_target_properties(${_target_name} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${B_INSTALL_DIR}/include")
        install(DIRECTORY "${B_INSTALL_DIR}/include/" DESTINATION "include")
    endif()

    if(_has_lib)
        file(GLOB_RECURSE _shared_libs "${B_INSTALL_DIR}/lib/*.so" "${B_INSTALL_DIR}/lib/*.so.*"
             "${B_INSTALL_DIR}/lib/*.dylib")

        if(B_STATIC_LIBS)
            set(_static_libs "")
            foreach(_lib ${B_STATIC_LIBS})
                if(IS_ABSOLUTE "${_lib}")
                    set(_lib_path "${_lib}")
                else()
                    set(_lib_path "${B_INSTALL_DIR}/lib/${_lib}")
                endif()
                if(NOT EXISTS "${_lib_path}")
                    spm_log_fatal("spm_create_target(NAME ${B_NAME}): static library entry '${_lib}' not found at '${_lib_path}'")
                endif()
                list(APPEND _static_libs "${_lib_path}")
            endforeach()
        else()
            file(GLOB_RECURSE _static_libs "${B_INSTALL_DIR}/lib/*.a" "${B_INSTALL_DIR}/lib/*.lib")
        endif()

        list(APPEND _link_libs ${_static_libs} ${_shared_libs})
    endif()

    if(_has_bin)
        install(
            DIRECTORY "${B_INSTALL_DIR}/bin/"
            DESTINATION "bin"
            FILE_PERMISSIONS
                OWNER_READ
                OWNER_WRITE
                OWNER_EXECUTE
                GROUP_READ
                GROUP_EXECUTE
                WORLD_READ
                WORLD_EXECUTE)
    endif()

    if(B_DEPENDENCIES)
        _spm_resolve_dependency_targets("${B_DEPENDENCIES}" _dep_targets)
        list(APPEND _link_libs ${_dep_targets})
    endif()

    if(_link_libs)
        install(DIRECTORY "${B_INSTALL_DIR}/lib/" DESTINATION "lib")
        set_target_properties(${_target_name} PROPERTIES INTERFACE_LINK_LIBRARIES "${_link_libs}")
        target_link_libraries(${_target_name} INTERFACE ${_link_libs})
    endif()

    if(B_EXTRA_DIRS)
        foreach(_pair ${B_EXTRA_DIRS})
            string(FIND "${_pair}" "::" _sep)
            if(_sep EQUAL -1)
                set(_src "${_pair}")
                set(_dest "${_pair}")
            else()
                string(SUBSTRING "${_pair}" 0 ${_sep} _src)
                math(EXPR _dest_start "${_sep} + 2")
                string(SUBSTRING "${_pair}" ${_dest_start} -1 _dest)
            endif()

            if(_dest STREQUAL "")
                spm_log_fatal("EXTRA_DIRS entry '${_pair}' has an empty destination")
            endif()

            if(NOT IS_ABSOLUTE "${_src}")
                set(_src "${B_INSTALL_DIR}/${_src}")
            endif()

            if(NOT IS_DIRECTORY "${_src}")
                spm_log_fatal("EXTRA_DIRS source '${_src}' is not a directory")
            endif()

            install(DIRECTORY "${_src}/" DESTINATION "${_dest}")
        endforeach()
    elseif(IS_DIRECTORY "${B_INSTALL_DIR}/extra")
        install(DIRECTORY "${B_INSTALL_DIR}/extra/" DESTINATION "share/${B_NAME}")
    endif()

    set(_config_dir "${B_INSTALL_DIR}/lib/cmake/${SPM_IMPORT_NAME}")
    file(MAKE_DIRECTORY "${_config_dir}")
    set(_config_file "${_config_dir}/${SPM_IMPORT_NAME}Config.cmake")

    if(NOT EXISTS "${_config_file}")
        file(WRITE "${_config_file}"
"# Auto-generated by spm_create_target(). Do not edit by hand.
get_filename_component(_spm_prefix \"\${CMAKE_CURRENT_LIST_DIR}/../../..\" ABSOLUTE)
")
    endif()

    set(_config_link_libs "")
    foreach(_lib ${_link_libs})
        if(TARGET "${_lib}")
            list(APPEND _config_link_libs "${_lib}")
        elseif(IS_ABSOLUTE "${_lib}" AND EXISTS "${_lib}")
            file(RELATIVE_PATH _rel "${B_INSTALL_DIR}" "${_lib}")
            list(APPEND _config_link_libs "\${_spm_prefix}/${_rel}")
        else()
            list(APPEND _config_link_libs "${_lib}")
        endif()
    endforeach()

    file(APPEND "${_config_file}" "
if(NOT TARGET ${SPM_IMPORT_NAME}::${B_NAME})
    add_library(${SPM_IMPORT_NAME}::${B_NAME} INTERFACE IMPORTED)
")
    if(_has_include)
        file(APPEND "${_config_file}"
            "    set_target_properties(${SPM_IMPORT_NAME}::${B_NAME} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES \"\${_spm_prefix}/include\")\n")
    endif()
    if(_config_link_libs)
        string(REPLACE ";" ";" _config_link_libs_str "${_config_link_libs}") # keep as list literal
        file(APPEND "${_config_file}"
            "    set_target_properties(${SPM_IMPORT_NAME}::${B_NAME} PROPERTIES INTERFACE_LINK_LIBRARIES \"${_config_link_libs_str}\")\n")
    endif()
    file(APPEND "${_config_file}" "endif()\n")

    install(DIRECTORY "${_config_dir}/" DESTINATION "lib/cmake/${SPM_IMPORT_NAME}")

    spm_log(
        "Target '${SPM_IMPORT_NAME}::${B_NAME}' registered from '${B_INSTALL_DIR}' (include=${_has_include}, lib=${_has_lib}, bin=${_has_bin})"
    )
endfunction()

# Creates a target from a package config
#
# spm_create_target_from_pkgconfig(
#   NAME <name>
#   MODULE <name>
#   [INSTALL_DIR <path>]
#   [PKGCONFIG_DIR <path>]
#   [OUT_TARGET_NAME <name>]
# )
function(spm_create_target_from_pkgconfig)
    set(oneValArgs NAME INSTALL_DIR MODULE PKGCONFIG_DIR OUT_TARGET_NAME)
    set(multiValArgs DEPENDENCIES)
    cmake_parse_arguments(B "" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    if(NOT B_NAME)
        spm_log_fatal("spm_create_target_from_pkgconfig requires a NAME")
    endif()
    if(NOT B_MODULE)
        spm_log_fatal("spm_create_target_from_pkgconfig requires MODULE (the .pc file's module name)")
    endif()
    if(NOT SPM_IMPORT_NAME)
        spm_log_fatal("SPM_IMPORT_NAME is not set (must run inside an SPM recipe build)")
    endif()
    if(NOT B_INSTALL_DIR)
        set(B_INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/install")
    endif()

    find_package(PkgConfig REQUIRED)

    if(B_PKGCONFIG_DIR)
        set(_pc_dirs "${B_PKGCONFIG_DIR}")
    else()
        set(_pc_dirs "${B_INSTALL_DIR}/lib/pkgconfig" "${B_INSTALL_DIR}/lib64/pkgconfig"
                     "${B_INSTALL_DIR}/share/pkgconfig")
    endif()

    set(_found_pc_dir "")
    foreach(_dir ${_pc_dirs})
        if(EXISTS "${_dir}/${B_MODULE}.pc")
            set(_found_pc_dir "${_dir}")
            break()
        endif()
    endforeach()
    if(NOT _found_pc_dir)
        spm_log_fatal("No '${B_MODULE}.pc' found under any of: ${_pc_dirs}")
    endif()

    set(_target_name "_spm_${SPM_IMPORT_NAME}_${B_NAME}")
    if(TARGET ${_target_name})
        spm_log_fatal("Target '${_target_name}' already exists")
    endif()

    string(MAKE_C_IDENTIFIER "_spmpc_${SPM_IMPORT_NAME}_${B_NAME}" _pc_prefix)
    if(TARGET PkgConfig::${_pc_prefix})
        spm_log_fatal("pkg-config target 'PkgConfig::${_pc_prefix}' already exists")
    endif()

    set(_saved_pkg_config_path "$ENV{PKG_CONFIG_PATH}")
    set(ENV{PKG_CONFIG_PATH} "${_found_pc_dir}")

    pkg_check_modules(${_pc_prefix} REQUIRED IMPORTED_TARGET GLOBAL "${B_MODULE}")

    set(ENV{PKG_CONFIG_PATH} "${_saved_pkg_config_path}")

    add_library(${_target_name} INTERFACE IMPORTED GLOBAL)
    set(_dep_targets "")
    if(B_DEPENDENCIES)
        _spm_resolve_dependency_targets("${B_DEPENDENCIES}" _dep_targets)
    endif()
    target_link_libraries(${_target_name} INTERFACE PkgConfig::${_pc_prefix} ${_dep_targets})
    add_library(${SPM_IMPORT_NAME}::${B_NAME} ALIAS ${_target_name})

    if(B_OUT_TARGET_NAME)
        set(${B_OUT_TARGET_NAME}
            ${_target_name}
            PARENT_SCOPE)
    endif()

    spm_log(
        "Registered target '${SPM_IMPORT_NAME}::${B_NAME}' from pkg-config module '${B_MODULE}' (${_found_pc_dir}, prefix ${_pc_prefix})"
    )

    if(IS_DIRECTORY "${B_INSTALL_DIR}/include")
        install(DIRECTORY "${B_INSTALL_DIR}/include/" DESTINATION "include")
    endif()
    if(IS_DIRECTORY "${B_INSTALL_DIR}/lib")
        install(DIRECTORY "${B_INSTALL_DIR}/lib/" DESTINATION "lib")
    endif()
    if(IS_DIRECTORY "${B_INSTALL_DIR}/bin")
        install(
            DIRECTORY "${B_INSTALL_DIR}/bin/"
            DESTINATION "bin"
            FILE_PERMISSIONS
                OWNER_READ
                OWNER_WRITE
                OWNER_EXECUTE
                GROUP_READ
                GROUP_EXECUTE
                WORLD_READ
                WORLD_EXECUTE)
    endif()
endfunction()
