include_guard(GLOBAL)

cmake_minimum_required(VERSION 3.24)

set(SPM_PARALLEL_JOBS
    "4"
    CACHE STRING "Parallel build jobs used when building a recipe")

set(SPM_LOGGING
    ON
    CACHE BOOL "SPM logging")

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
find_program(MESON_EXECUTABLE NAMES meson)
find_program(SPM_SH_EXECUTABLE NAMES sh bash)
find_program(MAKE_EXECUTABLE NAMES make mingw32-make)

macro(_spm_requires_autotools)
    if(NOT SPM_SH_EXECUTABLE)
        spm_log_fatal("no POSIX shell (sh/bash) was found; autotools recipes need one, e.g. via MSYS2 on Windows")
    endif()
    if(NOT MAKE_EXECUTABLE)
        spm_log_fatal("no make executable was found")
    endif()
endmacro()

macro(_spm_requires_meson)
    if(NOT MESON_EXECUTABLE)
        spm_log_fatal("no meson executable was found")
    endif()
endmacro()

macro(_spm_requires_git)
    if(NOT GIT_EXECUTABLE)
        spm_log_fatal("no git executable was found")
    endif()
endmacro()

macro(spm_log)
    if(SPM_LOGGING)
        message(STATUS "[SPM]: ${ARGV}.")
    endif()
endmacro()

function(spm_log_debug)
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
    spm_log_debug("Executing ${ARGV}")
    execute_process(${ARGV})
endmacro()

macro(spm_execute_process_serialized tag)
    set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-exec-${tag}")
    spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
    if(exists)
        return()
    endif()

    spm_execute_process(${tag})
    spm_write_stamp_file(FILE "${_stamp_file}")
endmacro()

#

# Checks whether a stamp file exists. Never writes.
#
# spm_check_stamp_file(
#   [FILE .spm-stamped]
#   OUT_VAR <var> # TRUE if the stamp already exists
# )
function(spm_check_stamp_file)
    set(oneValArgs FILE OUT_VAR)
    cmake_parse_arguments(B "" "${oneValArgs}" "" ${ARGN})

    if(NOT B_FILE)
        set(B_FILE "${CMAKE_CURRENT_SOURCE_DIR}/.spm-stamped")
    endif()

    if(NOT B_OUT_VAR)
        spm_log_fatal("spm_check_stamp_file() requires OUT_VAR")
    endif()

    if(EXISTS "${B_FILE}")
        set(${B_OUT_VAR}
            TRUE
            PARENT_SCOPE)
        spm_log_debug("Stamp file ${B_FILE} exists, ignoring")
    else()
        set(${B_OUT_VAR}
            FALSE
            PARENT_SCOPE)
    endif()
endfunction()

# Writes a stamp file. Call this only once the guarded operation has
# actually succeeded.
#
# spm_write_stamp_file(
#   [FILE .spm-stamped]
# )
function(spm_write_stamp_file)
    set(oneValArgs FILE)
    cmake_parse_arguments(B "" "${oneValArgs}" "" ${ARGN})

    if(NOT B_FILE)
        set(B_FILE "${CMAKE_CURRENT_SOURCE_DIR}/.spm-stamped")
    endif()

    get_filename_component(_stamp_dir "${B_FILE}" DIRECTORY)
    if(_stamp_dir AND NOT EXISTS "${_stamp_dir}")
        file(MAKE_DIRECTORY "${_stamp_dir}")
    endif()
    file(WRITE "${B_FILE}" "ok")
    spm_log_debug("Stamped '${B_FILE}'")
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
    set(oneValArgs NAME VERSION IMPORT_NAME OUT_INSTALL_DIR)
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
        spm_log_debug("Dependency '${R_NAME}@${R_VERSION}' already built elsewhere, reusing")
    else()
        include("${CMAKE_CURRENT_SOURCE_DIR}/spm.cmake")
        spm_require_package(${ARGN} OUT_INSTALL_DIR _dep_install_dir)
        if(NOT _dep_install_dir)
            spm_log_fatal("spm_requires(NAME ${R_NAME}) produced no install dir (unsupported on this platform?)")
        endif()
        set_property(GLOBAL PROPERTY SPM_DEP_INSTALL_DIR_${_pkg_key} "${_dep_install_dir}")
        set_property(GLOBAL APPEND PROPERTY SPM_REQUIRED_PACKAGES "${R_NAME}@${R_VERSION}")
    endif()

    if(R_OUT_INSTALL_DIR)
        set(${R_OUT_INSTALL_DIR}
            "${_dep_install_dir}"
            PARENT_SCOPE)
    endif()

    set_property(GLOBAL PROPERTY SPM_DEP_INSTALL_DIR_NAME_${_name} "${_dep_install_dir}")
    set_property(
        DIRECTORY
        APPEND
        PROPERTY SPM_RECIPE_DEPENDENCIES "${_name}")

    spm_log_debug("Recipe now depends on '${_name}' (installed at ${_dep_install_dir})")
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

#

function(_spm_resolve_dependency_prefixes deps out_var)
    get_property(
        _declared
        DIRECTORY
        PROPERTY SPM_RECIPE_DEPENDENCIES)
    set(_prefixes "")
    foreach(_dep ${deps})
        if(NOT _dep IN_LIST _declared)
            spm_log_fatal("DEPENDENCIES entry '${_dep}' was not declared via spm_requires() in this recipe")
        endif()
        get_property(_dep_dir GLOBAL PROPERTY SPM_DEP_INSTALL_DIR_NAME_${_dep})
        if(NOT _dep_dir)
            spm_log_fatal("No install directory recorded for dependency '${_dep}'")
        endif()
        list(APPEND _prefixes "${_dep_dir}")
    endforeach()
    set(${out_var}
        "${_prefixes}"
        PARENT_SCOPE)
endfunction()

macro(_spm_meson_msvc_env_push)
    set(_spm_meson_saved_path "$ENV{PATH}")
    set(_spm_meson_use_vsenv FALSE)
    if(MSVC)
        set(_spm_meson_cl "")
        if(CMAKE_C_COMPILER)
            set(_spm_meson_cl "${CMAKE_C_COMPILER}")
        elseif(CMAKE_CXX_COMPILER)
            set(_spm_meson_cl "${CMAKE_CXX_COMPILER}")
        endif()
        if(DEFINED ENV{VSINSTALLDIR} AND _spm_meson_cl)
            get_filename_component(_spm_meson_msvc_bin "${_spm_meson_cl}" DIRECTORY)
            file(TO_NATIVE_PATH "${_spm_meson_msvc_bin}" _spm_meson_msvc_bin)
            set(ENV{PATH} "${_spm_meson_msvc_bin};$ENV{PATH}")
            spm_log_debug("Prepended '${_spm_meson_msvc_bin}' to PATH for meson")
        else()
            set(_spm_meson_use_vsenv TRUE)
        endif()
    endif()
endmacro()

macro(_spm_meson_msvc_env_pop)
    set(ENV{PATH} "${_spm_meson_saved_path}")
endmacro()

# MESON

# Configure a meson target
#
# spm_meson_configure(
#   [SOURCE_DIR source]
#   [BUILD_DIR build]
#   [INSTALL_DIR install]
#   [OPTIONS ...]
#   [DEPENDENCIES ...]
#   [NATIVE_FILE <file>...]
#   [CROSS_FILE <file>...]
# )
function(spm_meson_configure)
    _spm_requires_meson()

    set(oneValArgs SOURCE_DIR BUILD_DIR INSTALL_DIR)
    set(multiValArgs OPTIONS DEPENDENCIES NATIVE_FILE CROSS_FILE)
    cmake_parse_arguments(B "" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    if(B_UNPARSED_ARGUMENTS)
        spm_log_fatal("spm_meson_configure() got unrecognized arguments: ${B_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT B_SOURCE_DIR)
        set(B_SOURCE_DIR source)
    endif()

    if(NOT B_BUILD_DIR)
        set(B_BUILD_DIR build)
    endif()

    if(NOT B_INSTALL_DIR)
        set(B_INSTALL_DIR install)
    endif()

    if(NOT IS_ABSOLUTE "${B_INSTALL_DIR}")
        set(B_INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/${B_INSTALL_DIR}")
    endif()

    if(IS_ABSOLUTE "${B_BUILD_DIR}")
        set(_build_abs "${B_BUILD_DIR}")
    else()
        set(_build_abs "${CMAKE_CURRENT_SOURCE_DIR}/${B_BUILD_DIR}")
    endif()

    set(_args --prefix "${B_INSTALL_DIR}" --libdir lib)

    # SPM_BUILD_TYPE uses CMake naming, map it onto meson's --buildtype.
    if(SPM_BUILD_TYPE)
        string(TOLOWER "${SPM_BUILD_TYPE}" _bt)
        if(_bt STREQUAL "debug")
            set(_meson_bt debug)
        elseif(_bt STREQUAL "release")
            set(_meson_bt release)
        elseif(_bt STREQUAL "relwithdebinfo")
            set(_meson_bt debugoptimized)
        elseif(_bt STREQUAL "minsizerel")
            set(_meson_bt minsize)
        else()
            spm_log_fatal("SPM_BUILD_TYPE '${SPM_BUILD_TYPE}' has no meson buildtype equivalent")
        endif()
        list(APPEND _args --buildtype "${_meson_bt}")
    endif()

    if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "")
        if(SPM_BUILD_SHARED_LIBS)
            list(APPEND _args --default-library shared)
        else()
            list(APPEND _args --default-library static)
        endif()
    endif()

    _spm_resolve_dependency_prefixes("${B_DEPENDENCIES}" _dep_prefixes)

    set(_pc_paths "")
    foreach(_prefix ${_dep_prefixes})
        foreach(_sub lib/pkgconfig lib64/pkgconfig share/pkgconfig)
            if(IS_DIRECTORY "${_prefix}/${_sub}")
                list(APPEND _pc_paths "${_prefix}/${_sub}")
            endif()
        endforeach()
    endforeach()
    if(_pc_paths)
        list(JOIN _pc_paths "," _pc_paths_str)
        list(APPEND _args "-Dpkg_config_path=${_pc_paths_str}")
    endif()

    set(_cmake_paths ${CMAKE_PREFIX_PATH} ${_dep_prefixes})
    if(_cmake_paths)
        list(JOIN _cmake_paths "," _cmake_paths_str)
        list(APPEND _args "-Dcmake_prefix_path=${_cmake_paths_str}")
    endif()

    foreach(_file ${B_NATIVE_FILE})
        list(APPEND _args --native-file "${_file}")
    endforeach()
    foreach(_file ${B_CROSS_FILE})
        list(APPEND _args --cross-file "${_file}")
    endforeach()

    set(_env_cmd "")
    if(NOT B_CROSS_FILE)
        set(_env_vars "")
        if(CMAKE_C_COMPILER)
            list(APPEND _env_vars "CC=${CMAKE_C_COMPILER}")
        endif()
        if(CMAKE_CXX_COMPILER)
            list(APPEND _env_vars "CXX=${CMAKE_CXX_COMPILER}")
        endif()
        if(_env_vars)
            set(_env_cmd ${CMAKE_COMMAND} -E env ${_env_vars})
        endif()
    endif()

    _spm_meson_msvc_env_push()
    if(_spm_meson_use_vsenv)
        list(APPEND _args --vsenv)
    endif()

    if(EXISTS "${_build_abs}/meson-private/coredata.dat")
        list(APPEND _args --reconfigure)
    endif()

    spm_execute_process(
        COMMAND
        ${_env_cmd}
        ${MESON_EXECUTABLE}
        setup
        ${_args}
        ${B_OPTIONS}
        "${B_BUILD_DIR}"
        "${B_SOURCE_DIR}"
        WORKING_DIRECTORY
        "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE
        _cfg_result
        OUTPUT_VARIABLE
        _cfg_output
        ERROR_VARIABLE
        _cfg_output)
    _spm_meson_msvc_env_pop()

    if(NOT _cfg_result EQUAL 0)
        spm_log_fatal("Configure failed:\n${_cfg_output}")
    else()
        spm_log_debug("Configure succeeded:\n${_cfg_output}")
    endif()
endfunction()

function(spm_meson_build)
    _spm_requires_meson()

    set(oneValArgs BUILD_DIR)
    cmake_parse_arguments(B "" "${oneValArgs}" "" ${ARGN})

    if(B_UNPARSED_ARGUMENTS)
        spm_log_fatal("spm_meson_build() got unrecognized arguments: ${B_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT B_BUILD_DIR)
        set(B_BUILD_DIR build)
    endif()

    _spm_meson_msvc_env_push()
    set(_vsenv_arg "")
    if(_spm_meson_use_vsenv)
        set(_vsenv_arg --vsenv)
    endif()

    spm_execute_process(
        COMMAND
        ${MESON_EXECUTABLE}
        compile
        ${_vsenv_arg}
        -C
        "${B_BUILD_DIR}"
        -j
        ${SPM_PARALLEL_JOBS}
        WORKING_DIRECTORY
        "${CMAKE_CURRENT_SOURCE_DIR}"
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
        ${MESON_EXECUTABLE}
        install
        -C
        "${B_BUILD_DIR}"
        --no-rebuild
        WORKING_DIRECTORY
        "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE
        _install_result
        OUTPUT_VARIABLE
        _install_output
        ERROR_VARIABLE
        _install_output)
    if(NOT _install_result EQUAL 0)
        spm_log_fatal("Install failed:\n${_install_output}")
    endif()
    _spm_meson_msvc_env_pop()
endfunction()

# AUTOTOOLS

# spm_autotools_configure(
#   [SOURCE_DIR source]
#   [BUILD_DIR build]
#   [INSTALL_DIR install]
#   [OPTIONS ...]
#   [DEPENDENCIES ...]
# )
function(spm_autotools_configure)
    _spm_requires_autotools()

    set(oneValArgs SOURCE_DIR BUILD_DIR INSTALL_DIR)
    set(multiValArgs OPTIONS DEPENDENCIES)
    cmake_parse_arguments(B "" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    if(NOT B_SOURCE_DIR)
        set(B_SOURCE_DIR source)
    endif()
    if(NOT B_BUILD_DIR)
        set(B_BUILD_DIR "${B_SOURCE_DIR}")
    endif()
    if(NOT B_INSTALL_DIR)
        set(B_INSTALL_DIR install)
    endif()
    if(NOT IS_ABSOLUTE "${B_INSTALL_DIR}")
        set(B_INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/${B_INSTALL_DIR}")
    endif()
    if(NOT IS_ABSOLUTE "${B_BUILD_DIR}")
        set(B_BUILD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/${B_BUILD_DIR}")
    endif()
    if(NOT IS_ABSOLUTE "${B_SOURCE_DIR}")
        set(_abs_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/${B_SOURCE_DIR}")
    else()
        set(_abs_source_dir "${B_SOURCE_DIR}")
    endif()

    _spm_resolve_dependency_prefixes("${B_DEPENDENCIES}" _dep_prefixes)

    string(SHA256 _stamp_key "${B_SOURCE_DIR}|${B_BUILD_DIR}|${B_INSTALL_DIR}|${B_OPTIONS}|${_dep_prefixes}")
    set(_stamp_file "${B_BUILD_DIR}/.spm-autotools-configured-${_stamp_key}")
    if(NOT SPM_FORCE_REBUILD)
        spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR _stamped)
        if(_stamped)
            spm_log_debug("autotools configure already done for '${B_SOURCE_DIR}' with these inputs, skipping")
            return()
        endif()
    endif()

    set(_cppflags "")
    set(_ldflags "")
    set(_pc_paths "")
    foreach(_prefix ${_dep_prefixes})
        if(IS_DIRECTORY "${_prefix}/include")
            list(APPEND _cppflags "-I${_prefix}/include")
        endif()
        if(IS_DIRECTORY "${_prefix}/lib")
            list(APPEND _ldflags "-L${_prefix}/lib")
        endif()
        foreach(_sub lib/pkgconfig lib64/pkgconfig share/pkgconfig)
            if(IS_DIRECTORY "${_prefix}/${_sub}")
                list(APPEND _pc_paths "${_prefix}/${_sub}")
            endif()
        endforeach()
    endforeach()

    if(MSVC)
        spm_write_msvc_compile_wrapper(_compile_wrapper)
        list(APPEND _env_args "CC=${SPM_SH_EXECUTABLE} ${_compile_wrapper} ${CMAKE_C_COMPILER} -nologo")
        if(CMAKE_CXX_COMPILER)
            list(APPEND _env_args "CXX=${SPM_SH_EXECUTABLE} ${_compile_wrapper} ${CMAKE_CXX_COMPILER} -nologo")
        endif()
        list(APPEND _env_args "RANLIB=:")
        if(EXISTS "${B_SOURCE_DIR}/build-aux/ar-lib")
            list(APPEND _env_args "AR=${SPM_SH_EXECUTABLE} ${B_SOURCE_DIR}/build-aux/ar-lib lib")
        endif()
    endif()

    set(_env_args "")
    if(_cppflags)
        list(JOIN _cppflags " " _cppflags_str)
        list(APPEND _env_args "CPPFLAGS=${_cppflags_str}")
    endif()
    if(_ldflags)
        list(JOIN _ldflags " " _ldflags_str)
        list(APPEND _env_args "LDFLAGS=${_ldflags_str}")
    endif()
    if(_pc_paths)
        list(JOIN _pc_paths ":" _pc_paths_str)
        list(APPEND _env_args "PKG_CONFIG_PATH=${_pc_paths_str}")
    endif()
    # if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    #     list(APPEND _env_args "CFLAGS=-fPIC")
    # endif()

    if(NOT B_BUILD_DIR STREQUAL _abs_source_dir)
        file(MAKE_DIRECTORY "${B_BUILD_DIR}")
        set(_configure_script "${_abs_source_dir}/configure")
    else()
        set(_configure_script "./configure")
    endif()

    spm_execute_process(
        COMMAND
        ${CMAKE_COMMAND}
        -E
        env
        ${_env_args}
        ${SPM_SH_EXECUTABLE}
        "${_configure_script}"
        "--prefix=${B_INSTALL_DIR}"
        ${B_OPTIONS}
        WORKING_DIRECTORY
        "${B_BUILD_DIR}"
        RESULT_VARIABLE
        _cfg_result
        OUTPUT_VARIABLE
        _cfg_output
        ERROR_VARIABLE
        _cfg_output)

    if(NOT _cfg_result EQUAL 0)
        spm_log_fatal("Configure failed:\n${_cfg_output}")
    else()
        spm_log_debug("Configure succeeded:\n${_cfg_output}")
    endif()

    spm_write_stamp_file(FILE "${_stamp_file}")
    if(EXISTS "${B_BUILD_DIR}/.spm-autotools-built")
        file(REMOVE "${B_BUILD_DIR}/.spm-autotools-built")
    endif()
endfunction()

# spm_write_msvc_compile_wrapper(OUT_VAR)
#
# Writes a script that lets a plain autoconf-generated
# `configure`/`make` drive cl.exe (or clang-cl/icl), which otherwise fails
# immediately because cl.exe doesn't understand GCC-style `-c -o file` flags.
function(spm_write_msvc_compile_wrapper OUT_VAR)
    set(_dir "${CMAKE_CURRENT_SOURCE_DIR}/msvc-compile-wrapper")
    set(_path "${_dir}/compile")

    if(NOT EXISTS "${_path}")
        file(MAKE_DIRECTORY "${_dir}")
        file(WRITE "${_path}" [=[#! /bin/sh
# Wrapper for compilers which do not understand '-c -o'.

scriptversion=2024-06-19.01; # UTC

# Copyright (C) 1999-2024 Free Software Foundation, Inc.
# Written by Tom Tromey <tromey@cygnus.com>.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# As a special exception to the GNU General Public License, if you
# distribute this file as part of a program that contains a
# configuration script generated by Autoconf, you may include it under
# the same distribution terms that you use for the rest of that program.

# This file is maintained in Automake, please report
# bugs to <bug-automake@gnu.org> or send patches to
# <automake-patches@gnu.org>.

nl='
'

# We need space, tab and new line, in precisely that order. Quoting is
# there to prevent tools from complaining about whitespace usage.
IFS=" ""	$nl"

file_conv=

# func_file_conv build_file lazy
# Convert a $build file to $host form and store it in $file
# Currently only supports Windows hosts. If the determined conversion
# type is listed in (the comma separated) LAZY, no conversion will
# take place.
func_file_conv ()
{
  file=$1
  case $file in
    / | /[!/]*) # absolute file, and not a UNC file
      if test -z "$file_conv"; then
	# lazily determine how to convert abs files
	case `uname -s` in
	  MINGW*)
	    file_conv=mingw
	    ;;
	  CYGWIN* | MSYS*)
	    file_conv=cygwin
	    ;;
	  *)
	    file_conv=wine
	    ;;
	esac
      fi
      case $file_conv/,$2, in
	*,$file_conv,*)
	  ;;
	mingw/*)
	  file=`cmd //C echo "$file " | sed -e 's/"\(.*\) " *$/\1/'`
	  ;;
	cygwin/* | msys/*)
	  file=`cygpath -m "$file" || echo "$file"`
	  ;;
	wine/*)
	  file=`winepath -w "$file" || echo "$file"`
	  ;;
      esac
      ;;
  esac
}

# func_cl_dashL linkdir
# Make cl look for libraries in LINKDIR
func_cl_dashL ()
{
  func_file_conv "$1"
  if test -z "$lib_path"; then
    lib_path=$file
  else
    lib_path="$lib_path;$file"
  fi
  linker_opts="$linker_opts -LIBPATH:$file"
}

# func_cl_dashl library
# Do a library search-path lookup for cl
func_cl_dashl ()
{
  lib=$1
  found=no
  save_IFS=$IFS
  IFS=';'
  for dir in $lib_path $LIB
  do
    IFS=$save_IFS
    if $shared && test -f "$dir/$lib.dll.lib"; then
      found=yes
      lib=$dir/$lib.dll.lib
      break
    fi
    if test -f "$dir/$lib.lib"; then
      found=yes
      lib=$dir/$lib.lib
      break
    fi
    if test -f "$dir/lib$lib.a"; then
      found=yes
      lib=$dir/lib$lib.a
      break
    fi
  done
  IFS=$save_IFS

  if test "$found" != yes; then
    lib=$lib.lib
  fi
}

# func_cl_wrapper cl arg...
# Adjust compile command to suit cl
func_cl_wrapper ()
{
  # Assume a capable shell
  lib_path=
  shared=:
  linker_opts=
  for arg
  do
    if test -n "$eat"; then
      eat=
    else
      case $1 in
	-o)
	  # configure might choose to run compile as 'compile cc -o foo foo.c'.
	  eat=1
	  case $2 in
	    *.o | *.lo | *.[oO][bB][jJ])
	      func_file_conv "$2"
	      set x "$@" -Fo"$file"
	      shift
	      ;;
	    *)
	      func_file_conv "$2"
	      set x "$@" -Fe"$file"
	      shift
	      ;;
	  esac
	  ;;
	-I)
	  eat=1
	  func_file_conv "$2" mingw
	  set x "$@" -I"$file"
	  shift
	  ;;
	-I*)
	  func_file_conv "${1#-I}" mingw
	  set x "$@" -I"$file"
	  shift
	  ;;
	-l)
	  eat=1
	  func_cl_dashl "$2"
	  set x "$@" "$lib"
	  shift
	  ;;
	-l*)
	  func_cl_dashl "${1#-l}"
	  set x "$@" "$lib"
	  shift
	  ;;
	-L)
	  eat=1
	  func_cl_dashL "$2"
	  ;;
	-L*)
	  func_cl_dashL "${1#-L}"
	  ;;
	-static)
	  shared=false
	  ;;
	-Wl,*)
	  arg=${1#-Wl,}
	  save_ifs="$IFS"; IFS=','
	  for flag in $arg; do
	    IFS="$save_ifs"
	    linker_opts="$linker_opts $flag"
	  done
	  IFS="$save_ifs"
	  ;;
	-Xlinker)
	  eat=1
	  linker_opts="$linker_opts $2"
	  ;;
	-*)
	  set x "$@" "$1"
	  shift
	  ;;
	*.cc | *.CC | *.cxx | *.CXX | *.[cC]++)
	  func_file_conv "$1"
	  set x "$@" -Tp"$file"
	  shift
	  ;;
	*.c | *.cpp | *.CPP | *.lib | *.LIB | *.Lib | *.OBJ | *.obj | *.[oO])
	  func_file_conv "$1" mingw
	  set x "$@" "$file"
	  shift
	  ;;
	*)
	  set x "$@" "$1"
	  shift
	  ;;
      esac
    fi
    shift
  done
  if test -n "$linker_opts"; then
    linker_opts="-link$linker_opts"
  fi
  exec "$@" $linker_opts
  exit 1
}

eat=

case $1 in
  '')
     echo "$0: No command. Try '$0 --help' for more information." 1>&2
     exit 1;
     ;;
  -h | --h*)
    cat <<\EOF
Usage: compile [--help] [--version] PROGRAM [ARGS]

Wrapper for compilers which do not understand '-c -o'.
Remove '-o dest.o' from ARGS, run PROGRAM with the remaining
arguments, and rename the output as expected.

If you are trying to build a whole package this is not the
right script to run: please start by reading the file 'INSTALL'.

Report bugs to <bug-automake@gnu.org>.
GNU Automake home page: <https://www.gnu.org/software/automake/>.
General help using GNU software: <https://www.gnu.org/gethelp/>.
EOF
    exit $?
    ;;
  -v | --v*)
    echo "compile (GNU Automake) $scriptversion"
    exit $?
    ;;
  cl | *[/\\]cl | cl.exe | *[/\\]cl.exe | \
  clang-cl | *[/\\]clang-cl | clang-cl.exe | *[/\\]clang-cl.exe | \
  icl | *[/\\]icl | icl.exe | *[/\\]icl.exe )
    func_cl_wrapper "$@"      # Doesn't return...
    ;;
esac

ofile=
cfile=

for arg
do
  if test -n "$eat"; then
    eat=
  else
    case $1 in
      -o)
	# configure might choose to run compile as 'compile cc -o foo foo.c'.
	# So we strip '-o arg' only if arg is an object.
	eat=1
	case $2 in
	  *.o | *.obj)
	    ofile=$2
	    ;;
	  *)
	    set x "$@" -o "$2"
	    shift
	    ;;
	esac
	;;
      *.c)
	cfile=$1
	set x "$@" "$1"
	shift
	;;
      *)
	set x "$@" "$1"
	shift
	;;
    esac
  fi
  shift
done

if test -z "$ofile" || test -z "$cfile"; then
  # If no '-o' option was seen then we might have been invoked from a
  # pattern rule where we don't need one. That is ok -- this is a
  # normal compilation that the losing compiler can handle. If no
  # '.c' file was seen then we are probably linking. That is also
  # ok.
  exec "$@"
fi

# Name of file we expect compiler to create.
cofile=`echo "$cfile" | sed 's|^.*[\\/]||; s|^[a-zA-Z]:||; s/\.c$/.o/'`

# Create the lock directory.
# Note: use '[/\\:.-]' here to ensure that we don't use the same name
# that we are using for the .o file. Also, base the name on the expected
# object file name, since that is what matters with a parallel build.
lockdir=`echo "$cofile" | sed -e 's|[/\\:.-]|_|g'`.d
while true; do
  if mkdir "$lockdir" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
# FIXME: race condition here if user kills between mkdir and trap.
trap "rmdir '$lockdir'; exit 1" 1 2 15

# Run the compile.
"$@"
ret=$?

if test -f "$cofile"; then
  test "$cofile" = "$ofile" || mv "$cofile" "$ofile"
elif test -f "${cofile}bj"; then
  test "${cofile}bj" = "$ofile" || mv "${cofile}bj" "$ofile"
fi

rmdir "$lockdir"
exit $ret

# Local Variables:
# mode: shell-script
# sh-indentation: 2
# eval: (add-hook 'before-save-hook 'time-stamp)
# time-stamp-start: "scriptversion="
# time-stamp-format: "%:y-%02m-%02d.%02H"
# time-stamp-time-zone: "UTC0"
# time-stamp-end: "; # UTC"
# End:
]=])
        # Mark executable (CMake 3.19+; spm-recipe.cmake already requires 3.24).
        file(CHMOD "${_path}"
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                        GROUP_READ GROUP_EXECUTE
                        WORLD_READ WORLD_EXECUTE)
    endif()

    set(${OUT_VAR} "${_path}" PARENT_SCOPE)
endfunction()

# spm_autotools_build(
#   [BUILD_DIR source]
# )
function(spm_autotools_build)
    _spm_requires_autotools()

    set(oneValArgs BUILD_DIR)
    cmake_parse_arguments(B "" "${oneValArgs}" "" ${ARGN})

    if(NOT B_BUILD_DIR)
        set(B_BUILD_DIR source)
    endif()
    if(NOT IS_ABSOLUTE "${B_BUILD_DIR}")
        set(B_BUILD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/${B_BUILD_DIR}")
    endif()

    set(_stamp_file "${B_BUILD_DIR}/.spm-autotools-built")
    if(NOT SPM_FORCE_REBUILD)
        spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR _stamped)
        if(_stamped)
            spm_log_debug("autotools build already done for '${B_BUILD_DIR}', skipping")
            return()
        endif()
    endif()

    spm_execute_process(
        COMMAND
        ${MAKE_EXECUTABLE}
        -j
        ${SPM_PARALLEL_JOBS}
        WORKING_DIRECTORY
        "${B_BUILD_DIR}"
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
        ${MAKE_EXECUTABLE}
        install
        WORKING_DIRECTORY
        "${B_BUILD_DIR}"
        RESULT_VARIABLE
        _install_result
        OUTPUT_VARIABLE
        _install_output
        ERROR_VARIABLE
        _install_output)
    if(NOT _install_result EQUAL 0)
        spm_log_fatal("Install failed:\n${_install_output}")
    endif()

    spm_write_stamp_file(FILE "${_stamp_file}")
endfunction()

# GIT

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

    set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-gitclone-${B_DESTINATION}")
    spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
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

    spm_log_debug("Cloning ${B_URL}")
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
        spm_log_debug("Checking out '${B_TAG}'")
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
            file(REMOVE_RECURSE "${_dest_file}")
            spm_log_fatal("git submodule update failed:\n${_submod_output}")
        endif()
    endif()

    spm_write_stamp_file(FILE "${_stamp_file}")
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
    list(APPEND _args "-DCMAKE_POSITION_INDEPENDENT_CODE=ON")

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
        spm_log_debug("Configure succeeded:\n${_cfg_output}")
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

# DOWNLOAD

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

    set(_hash_algo "")
    set(_hash_value "")
    if(B_EXPECTED_HASH)
        if(NOT B_EXPECTED_HASH MATCHES "^([A-Za-z0-9]+)=([0-9A-Fa-f]+)$")
            spm_log_fatal("spm_download_file(): EXPECTED_HASH must be of the form ALGO=value, got '${B_EXPECTED_HASH}'")
        endif()
        set(_hash_algo "${CMAKE_MATCH_1}")
        string(TOLOWER "${CMAKE_MATCH_2}" _hash_value)
    endif()

    string(SHA256 _stamp_key "${B_URL}|${B_DESTINATION}|${B_EXPECTED_HASH}")
    set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-download-${_stamp_key}")

    set(_cache_valid FALSE)
    if(NOT B_FORCE
       AND NOT SPM_FORCE_REBUILD
       AND EXISTS "${B_DESTINATION}")
        spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR _stamp_exists)
        if(_stamp_exists)
            if(_hash_algo)
                file(${_hash_algo} "${B_DESTINATION}" _actual_hash)
                string(TOLOWER "${_actual_hash}" _actual_hash)
                if(_actual_hash STREQUAL _hash_value)
                    set(_cache_valid TRUE)
                else()
                    spm_log_debug(
                        "Cached '${B_DESTINATION}' no longer matches the excepted hash (found ${_hash_algo}=${_actual_hash}, expected ${_hash_algo}=${_hash_value}), re-downloading"
                    )
                endif()
            else()
                set(_cache_valid TRUE)
            endif()
        endif()
    endif()

    if(_cache_valid)
        return()
    endif()

    if(EXISTS "${_stamp_file}")
        file(REMOVE "${_stamp_file}")
    endif()
    if(EXISTS "${B_DESTINATION}")
        file(REMOVE "${B_DESTINATION}")
    endif()

    get_filename_component(_dest_dir "${B_DESTINATION}" DIRECTORY)
    if(_dest_dir AND NOT EXISTS "${_dest_dir}")
        file(MAKE_DIRECTORY "${_dest_dir}")
    endif()

    set(_download_args
        "${B_URL}"
        "${B_DESTINATION}"
        STATUS
        _status
        LOG
        _log
        TLS_VERIFY
        ON)
    if(B_TIMEOUT)
        list(APPEND _download_args TIMEOUT "${B_TIMEOUT}")
    endif()
    if(B_HEADERS)
        list(APPEND _download_args HTTPHEADER "${B_HEADERS}")
    endif()
    if(B_EXPECTED_HASH)
        list(APPEND _download_args EXPECTED_HASH "${B_EXPECTED_HASH}")
    endif()

    spm_log_debug("Downloading '${B_URL}' to '${B_DESTINATION}'")

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
            spm_log_debug("Download attempt ${_attempt}/${B_RETRIES} failed (${_status_code}: ${_status_msg})")
            if(EXISTS "${B_DESTINATION}")
                file(REMOVE "${B_DESTINATION}")
            endif()
        endif()
    endwhile()

    if(NOT _ok)
        spm_log_fatal("Failed to download '${B_URL}' after ${B_RETRIES} attempt(s): ${_status_msg}\nLog:\n${_log}")
    endif()

    spm_write_stamp_file(FILE "${_stamp_file}")
    spm_log_debug("Downloaded '${B_DESTINATION}' (${_attempt} attempt(s))")
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

    spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
    if(${exists} AND EXISTS "${B_DESTINATION}")
        return()
    endif()

    if(EXISTS "${B_DESTINATION}")
        file(REMOVE_RECURSE "${B_DESTINATION}")
    endif()
    file(MAKE_DIRECTORY "${B_DESTINATION}")

    if(B_STRIP_COMPONENTS GREATER 0)
        set(_scratch_dir "${B_DESTINATION}.spm-extract-tmp")
        if(EXISTS "${_scratch_dir}")
            file(REMOVE_RECURSE "${_scratch_dir}")
        endif()
        file(MAKE_DIRECTORY "${_scratch_dir}")

        spm_log_debug("Extracting '${B_ARCHIVE}' to '${_scratch_dir}' (will strip ${B_STRIP_COMPONENTS} component(s))")
        file(ARCHIVE_EXTRACT INPUT "${B_ARCHIVE}" DESTINATION "${_scratch_dir}")

        set(_src_dir "${_scratch_dir}")
        foreach(_i RANGE 1 ${B_STRIP_COMPONENTS})
            file(GLOB _children "${_src_dir}/*")
            list(LENGTH _children _n_children)
            if(NOT _n_children EQUAL 1 OR NOT IS_DIRECTORY "${_children}")
                file(REMOVE_RECURSE "${_scratch_dir}")
                spm_log_fatal("spm_extract_archive(): cannot strip ${B_STRIP_COMPONENTS} component(s), "
                              "'${_src_dir}' does not contain exactly one subdirectory at depth ${_i}")
            endif()
            set(_src_dir "${_children}")
        endforeach()

        file(GLOB _final_children "${_src_dir}/*")
        foreach(_child ${_final_children})
            file(COPY "${_child}" DESTINATION "${B_DESTINATION}")
        endforeach()

        file(REMOVE_RECURSE "${_scratch_dir}")
    else()
        spm_log_debug("Extracting '${B_ARCHIVE}' to '${B_DESTINATION}'")
        file(ARCHIVE_EXTRACT INPUT "${B_ARCHIVE}" DESTINATION "${B_DESTINATION}")
    endif()

    spm_write_stamp_file(FILE "${_stamp_file}")
    spm_log_debug("Extracted '${B_ARCHIVE}' to '${B_DESTINATION}'")

    if(B_DELETE_ARCHIVE)
        file(REMOVE "${B_ARCHIVE}")
        spm_log_debug("Deleted archive '${B_ARCHIVE}'")
    endif()
endfunction()

# PATCHING

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
        set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-patch-${_hash}")
        spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
        if(exists)
            continue()
        endif()

        spm_log_debug("Applying patch '${_patch}'")
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

        spm_write_stamp_file(FILE "${_stamp_file}")
    endforeach()
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
# spm_create_dummy_target(
#   NAME <name>
#   [OUT_TARGET_NAME <name>]
#   [STATIC_LIBS <libs>...]
# )
function(spm_create_dummy_target)
    set(_options "")
    set(_one_value_args NAME OUT_TARGET_NAME)
    set(_multi_value_args DEPENDENCIES)
    cmake_parse_arguments(_sdt "${_options}" "${_one_value_args}" "${_multi_value_args}" ${ARGN})

    if(NOT _sdt_NAME)
        message(FATAL_ERROR "spm_create_dummy_target: NAME is required")
    endif()

    set(_sdt_target_name "${_sdt_NAME}_dummy")
    set(SPM_IMPORT_NAME "${_sdt_NAME}")

    if(NOT TARGET ${_sdt_target_name})
        add_library(${_sdt_target_name} INTERFACE)

        if(_sdt_DEPENDENCIES)
            target_link_libraries(${_sdt_target_name} INTERFACE ${_sdt_DEPENDENCIES})
        endif()
    endif()

    if(NOT TARGET ${_sdt_NAME}::${_sdt_NAME})
        add_library(${_sdt_NAME}::${_sdt_NAME} ALIAS ${_sdt_target_name})
    endif()

    set(_config_dir "${CMAKE_CURRENT_BINARY_DIR}/${SPM_IMPORT_NAME}-dummy-config")
    file(MAKE_DIRECTORY "${_config_dir}")

    set(_config_file "${_config_dir}/${SPM_IMPORT_NAME}Config.cmake")
    file(WRITE "${_config_file}"
"# Auto-generated dummy config for ${SPM_IMPORT_NAME} (no build artifacts;
# satisfied by the system or a no-op on this platform).
if(NOT TARGET ${SPM_IMPORT_NAME}::${SPM_IMPORT_NAME})
    add_library(${SPM_IMPORT_NAME}::${SPM_IMPORT_NAME} INTERFACE IMPORTED)
")

    if(_sdt_DEPENDENCIES)
        file(APPEND "${_config_file}"
"    set_target_properties(${SPM_IMPORT_NAME}::${SPM_IMPORT_NAME} PROPERTIES
        INTERFACE_LINK_LIBRARIES \"${_sdt_DEPENDENCIES}\")
")
    endif()

    file(APPEND "${_config_file}" "endif()\n")

    install(DIRECTORY "${_config_dir}/" DESTINATION "lib/cmake/${SPM_IMPORT_NAME}")

    if(_sdt_OUT_TARGET_NAME)
        set(${_sdt_OUT_TARGET_NAME} ${_sdt_target_name})
    endif()
endfunction()

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
                    spm_log_fatal(
                        "spm_create_target(NAME ${B_NAME}): static library entry '${_lib}' not found at '${_lib_path}'")
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
        file(
            WRITE "${_config_file}"
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

    file(
        APPEND "${_config_file}"
        "
if(NOT TARGET ${SPM_IMPORT_NAME}::${B_NAME})
    add_library(${SPM_IMPORT_NAME}::${B_NAME} INTERFACE IMPORTED)
")
    if(_has_include)
        file(
            APPEND "${_config_file}"
            "    set_target_properties(${SPM_IMPORT_NAME}::${B_NAME} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES \"\${_spm_prefix}/include\")\n"
        )
    endif()
    if(_config_link_libs)
        string(REPLACE ";" ";" _config_link_libs_str "${_config_link_libs}") # keep as list literal
        file(
            APPEND "${_config_file}"
            "    set_target_properties(${SPM_IMPORT_NAME}::${B_NAME} PROPERTIES INTERFACE_LINK_LIBRARIES \"${_config_link_libs_str}\")\n"
        )
    endif()
    file(APPEND "${_config_file}" "endif()\n")

    install(DIRECTORY "${_config_dir}/" DESTINATION "lib/cmake/${SPM_IMPORT_NAME}")

    spm_log_debug(
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

    set(_saved_prefix_path "${CMAKE_PREFIX_PATH}")
    set(CMAKE_PREFIX_PATH "")

    set(_saved_pkg_config_path "$ENV{PKG_CONFIG_PATH}")
    set(ENV{PKG_CONFIG_PATH} "${_found_pc_dir}")

    pkg_check_modules(${_pc_prefix} REQUIRED IMPORTED_TARGET GLOBAL "${B_MODULE}")

    set(ENV{PKG_CONFIG_PATH} "${_saved_pkg_config_path}")
    set(CMAKE_PREFIX_PATH "${_saved_prefix_path}")

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

    spm_log_debug(
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
