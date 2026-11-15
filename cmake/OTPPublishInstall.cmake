# Publish an already finalized installation using filesystem renames. The
# private stage is a direct child of its destination, keeping moves on the same
# filesystem and leaving mapped executables on their original inodes.
cmake_minimum_required(VERSION 3.25)
include_guard(GLOBAL)

function(_otp_install_path output spelling)
    # lstat-style symlink checks can follow a link spelled with a final / or /.
    # Remove those suffixes without collapsing .. across a directory symlink.
    set(_path "${spelling}")
    while("${_path}" MATCHES "/(\\.)?/*$")
        string(REGEX REPLACE "/(\\.)?/*$" "" _path "${_path}")
    endwhile()
    if(_path STREQUAL "")
        set(_path "/")
    endif()
    set(${output} "${_path}" PARENT_SCOPE)
endfunction()

function(_otp_install_check_directory directory)
    if(IS_SYMLINK "${directory}")
        message(FATAL_ERROR "Installation destination directory is a symlink: ${directory}")
    elseif(EXISTS "${directory}" AND NOT IS_DIRECTORY "${directory}")
        message(FATAL_ERROR "Installation destination directory is not a directory: ${directory}")
    endif()
endfunction()

function(_otp_install_rename source destination)
    # Windows cannot replace an existing open destination using MoveFileEx,
    # even when all handles permit deletion. The native preflight guard holds
    # those handles to exclude new readers: move the old entry to an unused
    # private-stage name first, then publish and retire it. Unix rename already
    # replaces the entry while preserving mappings of the previous inode.
    set(_backup "")
    if(WIN32 AND (EXISTS "${destination}" OR IS_SYMLINK "${destination}"))
        get_filename_component(_source_parent "${source}" DIRECTORY)
        string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef _nonce)
        set(_backup "${_source_parent}/.otp-replaced-${_nonce}")
        file(RENAME "${destination}" "${_backup}" RESULT _result)
        if(NOT _result STREQUAL "0")
            message(FATAL_ERROR "Cannot retire installed entry ${destination}: ${_result}")
        endif()
    endif()
    file(RENAME "${source}" "${destination}" RESULT _result)
    if(NOT _result STREQUAL "0")
        if(NOT _backup STREQUAL "")
            file(RENAME "${_backup}" "${destination}" RESULT _rollback)
            if(NOT _rollback STREQUAL "0")
                message(FATAL_ERROR "Cannot publish ${source}; old entry remains at ${_backup}: ${_rollback}")
            endif()
        endif()
        message(FATAL_ERROR "Cannot publish ${source} as ${destination}: ${_result}")
    endif()
    if(NOT _backup STREQUAL "")
        file(REMOVE "${_backup}")
    endif()
endfunction()

function(_otp_install_merge_directory source destination)
    if(NOT EXISTS "${destination}")
        # Moving a new subtree preserves all of its directory and leaf modes.
        # Existing destination directory permissions are deliberately retained.
        _otp_install_rename("${source}" "${destination}")
        return()
    endif()

    file(GLOB _children LIST_DIRECTORIES TRUE RELATIVE "${source}" "${source}/*")
    foreach(_child IN LISTS _children)
        set(_source "${source}/${_child}")
        set(_destination "${destination}/${_child}")
        if(IS_DIRECTORY "${_source}" AND NOT IS_SYMLINK "${_source}")
            _otp_install_merge_directory("${_source}" "${_destination}")
        else()
            # A staged symlink, including a directory symlink, is a leaf. Rename
            # replaces the destination entry without following a leaf symlink.
            _otp_install_rename("${_source}" "${_destination}")
        endif()
    endforeach()
    file(REMOVE_RECURSE "${source}")
endfunction()

function(otp_publish_install stage prefix)
    _otp_install_path(stage "${stage}")
    _otp_install_path(prefix "${prefix}")
    if(IS_SYMLINK "${stage}" OR NOT IS_DIRECTORY "${stage}")
        message(FATAL_ERROR "Installation stage must be a real private directory: ${stage}")
    endif()
    file(REAL_PATH "${stage}" _stage)
    file(REAL_PATH "${prefix}" _prefix)
    get_filename_component(_parent "${_stage}" DIRECTORY)
    get_filename_component(_name "${_stage}" NAME)
    if(NOT _parent STREQUAL _prefix OR NOT _name MATCHES "^\\.otp-install-")
        message(FATAL_ERROR "Installation stage must be a private child of the selected prefix")
    endif()

    # Complete the preflight before moving any leaf or subtree. Do not follow
    # staged directory symlinks while enumerating the destination closure.
    _otp_install_check_directory("${prefix}")
    file(LOCK "${_prefix}/.otp-publish.lock" GUARD FUNCTION TIMEOUT 60)
    file(GLOB_RECURSE _entries LIST_DIRECTORIES TRUE RELATIVE "${_stage}" "${_stage}/*")
    foreach(_entry IN LISTS _entries)
        set(_source "${_stage}/${_entry}")
        set(_destination "${_prefix}/${_entry}")
        if(IS_DIRECTORY "${_source}" AND NOT IS_SYMLINK "${_source}")
            _otp_install_check_directory("${_destination}")
        elseif(IS_DIRECTORY "${_destination}" AND NOT IS_SYMLINK "${_destination}")
            message(FATAL_ERROR "Installation destination leaf is a directory: ${_destination}")
        endif()
    endforeach()

    _otp_install_merge_directory("${_stage}" "${_prefix}")
endfunction()

# Standalone entry point for the publication-boundary tests.
if(CMAKE_SCRIPT_MODE_FILE STREQUAL CMAKE_CURRENT_LIST_FILE)
    if(NOT DEFINED OTP_INSTALL_STAGE OR NOT DEFINED OTP_INSTALL_PREFIX)
        message(FATAL_ERROR "Set OTP_INSTALL_STAGE and OTP_INSTALL_PREFIX")
    endif()
    otp_publish_install("${OTP_INSTALL_STAGE}" "${OTP_INSTALL_PREFIX}")
endif()
