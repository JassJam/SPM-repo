include_guard(GLOBAL)

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
        if(_entry MATCHES "^(.*)@(.*)$" AND CMAKE_MATCH_1 STREQUAL R_NAME AND NOT CMAKE_MATCH_2 STREQUAL R_VERSION)
            spm_log_fatal("Version conflict for '${R_NAME}': already resolved at '${CMAKE_MATCH_2}', now requested at '${R_VERSION}'")
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
    set_property(DIRECTORY APPEND PROPERTY SPM_RECIPE_DEPENDENCIES "${_name}")

    spm_log("Recipe now depends on '${_name}' (installed at ${_dep_install_dir})")
endfunction()

function(_spm_resolve_dependency_targets deps out_var)
    get_property(_declared DIRECTORY PROPERTY SPM_RECIPE_DEPENDENCIES)
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
    set(${out_var} "${_resolved}" PARENT_SCOPE)
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
        get_property(_declared DIRECTORY PROPERTY SPM_RECIPE_DEPENDENCIES)
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
        string(REPLACE ";" "\\;" _dep_prefix_paths_escaped "${_dep_prefix_paths}")
        set(_prefix_path_arg "-DCMAKE_PREFIX_PATH=${_dep_prefix_paths_escaped}")
    endif()

    set(_args "")
    list(APPEND _args "-DCMAKE_INSTALL_PREFIX=${B_INSTALL_DIR}")

    spm_execute_process(
        COMMAND
        ${CMAKE_COMMAND}
        -S ${B_SOURCE_DIR}
        -B ${B_BUILD_DIR}
        -G "${CMAKE_GENERATOR}"
        -C "spm-input.cmake"
        ${_args}
        ${_prefix_path_arg}
        ${B_OPTIONS}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE _cfg_result
        OUTPUT_VARIABLE _cfg_output
        ERROR_VARIABLE _cfg_output)

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
#   [EXTRA_DIRS <source>[:<destination>] ...]
# )
function(spm_create_target)
    set(oneValArgs NAME INSTALL_DIR OUT_TARGET_NAME)
    set(multiValArgs EXTRA_DIRS DEPENDENCIES)
    cmake_parse_arguments(B "" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    if(NOT B_INSTALL_DIR)
        set(B_INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/install")
    endif()

    if(NOT B_NAME)
        spm_log_fatal("spm_create_target requires a name")
    endif()

    if(NOT SPM_IMPORT_NAME)
        spm_log_fatal("SPM_IMPORT_NAME is not set (spm_create_target must run inside an SPM recipe build)")
    endif()

    set(_target_name "_spm_${SPM_IMPORT_NAME}_${B_NAME}")
    if(TARGET ${_target_name})
        spm_log_fatal("Target '${_target_name}' already exists")
    endif()
    if(B_OUT_TARGET_NAME)
        set(${B_OUT_TARGET_NAME} ${_target_name} PARENT_SCOPE)
    endif()

    add_library(${_target_name} INTERFACE IMPORTED GLOBAL)
    add_library(${SPM_IMPORT_NAME}::${B_NAME} ALIAS ${_target_name})
    spm_log("Registered target '${SPM_IMPORT_NAME}::${B_NAME}'")

    set(_link_libs "")

    if(IS_DIRECTORY "${B_INSTALL_DIR}/include")
        set_target_properties(${_target_name} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${B_INSTALL_DIR}/include")
        install(DIRECTORY "${B_INSTALL_DIR}/include/" DESTINATION "include")
    endif()

    if(IS_DIRECTORY "${B_INSTALL_DIR}/lib")
        file(GLOB_RECURSE _static_libs
            "${B_INSTALL_DIR}/lib/*.a"
            "${B_INSTALL_DIR}/lib/*.so"
            "${B_INSTALL_DIR}/lib/*.so.*"
            "${B_INSTALL_DIR}/lib/*.dylib"
            "${B_INSTALL_DIR}/lib/*.lib"
            "${B_INSTALL_DIR}/lib/*.dll")
        list(APPEND _link_libs ${_static_libs})
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

    if(B_DEPENDENCIES)
        _spm_resolve_dependency_targets("${B_DEPENDENCIES}" _dep_targets)
        list(APPEND _link_libs ${_dep_targets})
    endif()

    if(_link_libs)
        set_target_properties(${_target_name} PROPERTIES INTERFACE_LINK_LIBRARIES "${_link_libs}")
    endif()

    if(B_EXTRA_DIRS)
        foreach(_pair ${B_EXTRA_DIRS})
            string(FIND "${_pair}" ":" _sep)
            if(_sep EQUAL -1)
                set(_src "${_pair}")
                set(_dest "${_pair}")
            else()
                string(SUBSTRING "${_pair}" 0 ${_sep} _src)
                math(EXPR _dest_start "${_sep} + 1")
                string(SUBSTRING "${_pair}" ${_dest_start} -1 _dest)
            endif()
            if(NOT IS_DIRECTORY "${_src}")
                spm_log_fatal("EXTRA_DIRS source '${_src}' is not a directory")
            endif()
            install(DIRECTORY "${_src}/" DESTINATION "${_dest}")
        endforeach()
    elseif(IS_DIRECTORY "${B_INSTALL_DIR}/extra")
        install(DIRECTORY "${B_INSTALL_DIR}/extra/" DESTINATION "share/${B_NAME}")
    endif()

    spm_log("Target '${B_NAME}' created from '${B_INSTALL_DIR}'")
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
        set(_pc_dirs
            "${B_INSTALL_DIR}/lib/pkgconfig"
            "${B_INSTALL_DIR}/lib64/pkgconfig"
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
        set(${B_OUT_TARGET_NAME} ${_target_name} PARENT_SCOPE)
    endif()

    spm_log("Registered target '${SPM_IMPORT_NAME}::${B_NAME}' from pkg-config module '${B_MODULE}' (${_found_pc_dir}, prefix ${_pc_prefix})")

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
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    endif()
endfunction()
