#-------------------------------------------------------------------
# This file is part of the CMake build system for OGRE
#     (Object-oriented Graphics Rendering Engine)
# For the latest info, see http://www.ogre3d.org/
#
# The contents of this file are placed in the public domain. Feel
# free to make use of it in any way you like.
#-------------------------------------------------------------------

# check the contents of a given source file. If they differ from the
# expected content, or the file does not exist, rewrite it with the
# provided content.
# This function is used in order to update Unity build files only when
# necessary. If we rewrote them unconditionally, it might trigger an
# unnecessary rebuild of the file.
function(check_and_update_file FILENAME CONTENT)
  # read current file contents
  if (EXISTS ${FILENAME})
    file(READ ${FILENAME} _CUR)
  else ()
    # create empty file
    file(WRITE ${FILENAME} "")
    set(_CUR "")
  endif ()
  if (NOT _CUR STREQUAL CONTENT)
    # rewrite file with new contents
    message(STATUS "  Updating ${FILENAME}...")
    file(WRITE ${FILENAME} ${CONTENT})
  else ()
    message(STATUS "  ${FILENAME} is up to date.")
  endif ()
endfunction()


# generate unity build files for the given target.
# If in the list of source files the key word SEPARATE is specified, then
# any source file after that will be compiled separately.
macro(create_unity_build_files TARGETNAME)
  # list of files that can't be included in the Unity build files
  set(_SKIP_FILE_LIST "")
  if(APPLE AND NOT OGRE_BUILD_PLATFORM_APPLE_IOS)
    list(APPEND _SKIP_FILE_LIST
      "gkRayTestNode.cpp"
      "gkParticleManager.cpp"
      "gkOgreParticleAffector.cpp"
      "gkOgreParticleEmitter.cpp"
    )
  endif()

  # first step: build the primary and separate lists
  set(_PRIMARY "")
  set(_EXCLUDES "")
  set(_SEP FALSE)
  foreach(_FILE ${ARGN})
    if (_FILE STREQUAL "SEPARATE")
      set(_SEP TRUE)
    else ()
      if (_SEP)
        list(APPEND _EXCLUDES ${_FILE})
      else ()
        list(APPEND _PRIMARY ${_FILE})
      endif ()
    endif()
  endforeach()
  set(_SOURCES ${_PRIMARY} ${_EXCLUDES})
  list(REMOVE_DUPLICATES _SOURCES)

  if (OGRE_UNITY_BUILD)
    include_directories(${CMAKE_CURRENT_SOURCE_DIR})
    # create Unity compilation units
    # all source files given will be put into a certain number of
    # compilation units.
    # if certain source files should be excluded from the unity build
    # and built separately, they need to also be named in the SEPARATE
    # list.
    set(_FILE_NUM 0)
    set(_FILE_CNT 0)
    set(_FILE_CONTENTS "")
    message(STATUS "Creating Unity build files for target ${TARGETNAME}")
    foreach(_FILE ${_PRIMARY})
      # test if file is more than just a header
      get_filename_component(_EXT ${_FILE} EXT)
      list(FIND _EXCLUDES ${_FILE} _EXCLUDED)
      if ((_EXT STREQUAL ".cpp") AND (_EXCLUDED EQUAL "-1"))
        set(_SKIP FALSE)
        if (APPLE)
          # test if file imports Objective-C headers
          file(READ ${_FILE} _CUR)
          string(REGEX MATCH
            "\n *# *import *[<\"][^>\"]*[>\"]"
            _MATCH
            ${_CUR}
          )
          if (NOT _MATCH STREQUAL "")
            set(_SKIP TRUE)
          endif()
          # test if file is in skip list
          foreach(_SKIP_FILE ${_SKIP_FILE_LIST})
            string(FIND ${_FILE} ${_SKIP_FILE} _EXCLUDED)
            if (NOT (_EXCLUDED EQUAL "-1"))
              set(_SKIP TRUE)
            endif()
          endforeach()
        endif()
        if (NOT _SKIP)
          # add file only if it does not import Objetive-C headers
          set(_FILE_CONTENTS "${_FILE_CONTENTS}\#include \"${_FILE}\"\n")
          math(EXPR _FILE_CNT "${_FILE_CNT}+1")
          if(_FILE_CNT EQUAL OGRE_UNITY_FILES_PER_UNIT)
            set(_FILENAME "${OGRE_BINARY_DIR}/${TARGETNAME}/compile_${TARGETNAME}_${_FILE_NUM}.cpp")
            check_and_update_file(${_FILENAME} ${_FILE_CONTENTS})
            math(EXPR _FILE_NUM "${_FILE_NUM}+1")
            set(_FILE_CNT 0)
            set (_FILE_CONTENTS "")
            list(APPEND _SOURCES ${_FILENAME})
          endif()
          # exclude the original source file from the compilation
          set_source_files_properties(${_FILE} PROPERTIES LANGUAGE "" HEADER_FILE_ONLY TRUE)
        endif()
      endif()
    endforeach()
    # don't forget the last set of files
	if (NOT _FILE_CONTENTS STREQUAL "")
      set(_FILENAME "${OGRE_BINARY_DIR}/${TARGETNAME}/compile_${TARGETNAME}_${_FILE_NUM}.cpp")
      check_and_update_file(${_FILENAME} ${_FILE_CONTENTS})
      list(APPEND _SOURCES ${_FILENAME})
	endif ()
  endif()
endmacro()


# add a new library target
# usage: ogre_add_library(TARGETNAME LIBTYPE SOURCE_FILES [SEPARATE SOURCE_FILES])
function(ogre_add_library TARGETNAME LIBTYPE)
  create_unity_build_files(${TARGETNAME} ${ARGN})
  add_library(${TARGETNAME} ${LIBTYPE} ${_SOURCES})
endfunction(ogre_add_library)


# add a new executable target
# usage: ogre_add_executable(TARGETNAME [WIN32] [MACOSX_BUNDLE] SOURCE_FILES [SEPARATE SOURCE_FILES])
function(ogrekit_add_executable TARGETNAME)
  # test if WIN32 or MACOSX_BUNDLE options were provided
  set(_WIN32 "")
  set(_OSX "")
  list(FIND ARGN "WIN32" _W32_IDX)
  if (_W32_IDX GREATER "-1")
    set(_WIN32 "WIN32")
    list(REMOVE_AT ARGN ${_W32_IDX})
  endif ()
  list(FIND ARGN "MACOSX_BUNDLE" _OSX_IDX)
  if (_OSX_IDX GREATER "-1")
    set(_OSX "MACOSX_BUNDLE")
    list(REMOVE_AT ARGN ${_OSX_IDX})
  endif ()
  create_unity_build_files(${TARGETNAME} ${ARGN})
  add_executable(${TARGETNAME} ${_WIN32} ${_OSX} ${_SOURCES})
endfunction()

macro(ogrekit_add_library TARGETNAME LIBTYPE)  
  set(TMP_UTITY_BUILD ${OGRE_UNITY_BUILD})
  set(OGRE_UNITY_BUILD ${OGREKIT_UNITY_BUILD})
  
  create_unity_build_files(${TARGETNAME} ${ARGN})  
  
  set(OGRE_UNITY_BUILD ${TMP_UTITY_BUILD})

  add_library(${TARGETNAME} ${LIBTYPE} ${_SOURCES})
endmacro()

# function(ogrekit_add_executable TARGETNAME)
  # ogre_add_executable(${TARGETNAME} ${ARGN})
# endfunction()

