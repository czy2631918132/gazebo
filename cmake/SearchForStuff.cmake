include (${gazebo_cmake_dir}/GazeboUtils.cmake)
include (CheckCXXSourceCompiles)

set (INCLUDE_WEBGAZEBO ON CACHE BOOL "Build webgazebo" FORCE)
set (OGRE_LIBRARY_PATH "/usr/local/lib" CACHE INTERNAL "Ogre library path")

set (assimp_include_dirs "" CACHE STRING "Assimp include paths. Use this to override automatic detection.")
set (assimp_library_dirs "" CACHE STRING "Assimp library paths. Use this to override automatic detection.")
set (assimp_libraries "" CACHE STRING "Assimp libraries Use this to override automatic detection.")

set (boost_include_dirs "" CACHE STRING "Boost include paths. Use this to override automatic detection.")
set (boost_library_dirs "" CACHE STRING "Boost library paths. Use this to override automatic detection.")
set (boost_libraries "" CACHE STRING "Boost libraries. Use this to override automatic detection.")

set (bullet_include_dirs "" CACHE STRING "Bullet include paths. Use this to override automatic detection.")
set (bullet_library_dirs "" CACHE STRING "Bullet library paths. Use this to override automatic detection.")
set (bullet_lflags "" CACHE STRING "Bullet lflags Use this to override automatic detection.")
set (bullet_cflags "-DBT_USE_DOUBLE_PRECISION -DBT_EULER_DEFAULT_ZYX" CACHE STRING "Bullet Dynamics C compile flags exported by rospack.")

set (parallel_quickstep_include_dirs "" CACHE STRING "parallel_quickstep CUDA include paths. Use this to override automatic detection.")
set (parallel_quickstep_library_dirs "" CACHE STRING "parallel_quickstep CUDA library paths. Use this to override automatic detection.")
set (parallel_quickstep_library "" CACHE STRING "parallel_quickstep CUDA library names. Use this to override automatic detection.")
set (parallel_quickstep_lflags "" CACHE STRING "parallel_quickstep CUDA lflags Use this to override automatic detection.")
set (parallel_quickstep_cflags "" CACHE STRING "parallel_quickstep CUDA cflags Use this to override automatic detection.")

set (threadpool_include_dirs "" CACHE STRING "Threadpool include paths. Use this to override automatic detection.")

SET (gazebo_lflags "" CACHE STRING "Linker flags such as rpath for gazebo executable.")

set (GTK2_LIBRARIES "" CACHE STRING "WX GTK2 include paths. Use this to override automatic detection.")
set (GTK2_INCLUDE_DIRS "" CACHE STRING "WX GTK2 include paths. Use this to override automatic detection.")

include (${gazebo_cmake_dir}/FindOS.cmake)
include (FindPkgConfig)
include (FindwxWidgets)
include (${gazebo_cmake_dir}/FindFreeimage.cmake)

include (FindOpenGL)
if (NOT OPENGL_FOUND)
  BUILD_ERROR ("Missing: OpenGL")
else ()
 APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                       ${gazeboserver_include_dirs_desc} 
                       ${OPENGL_INCLUDE_DIR})
 APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                       ${gazeboserver_link_libs_desc} 
                       ${OPENGL_LIBRARIES})
endif ()


########################################
# Find packages
if (PKG_CONFIG_FOUND)

  #################################################
  # Find TBB
  pkg_check_modules(TBB tbb)
  IF (NOT TBB_FOUND)
    BUILD_ERROR ("Missing: TBB - Threading Building Blocks")
  ELSE (NOT TBB_FOUND)
    APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                          ${gazeboserver_include_dirs_desc} 
                          ${TBB_INCLUDE_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_dirs 
                          ${gazeboserver_link_dirs_desc} 
                          ${TBB_LIBRARY_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${TBB_LINK_LIBS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${TBB_LIBRARIES})
    APPEND_TO_CACHED_LIST(gazeboserver_ldflags
                          ${gazeboserver_ldflags_desc} 
                          ${TBB_LDFLAGS})
  ENDIF (NOT TBB_FOUND)



  #################################################
  # Find ODE
  pkg_check_modules(ODE ode>=${ODE_VERSION})
  IF (NOT ODE_FOUND)
    BUILD_ERROR ("Missing: ODE(http://www.ode.org)")
    SET (INCLUDE_ODE FALSE CACHE BOOL "Include support for ODE")
  ELSE (NOT ODE_FOUND)
    SET (INCLUDE_ODE TRUE CACHE BOOL "Include support for ODE")
  
    APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                          ${gazeboserver_include_dirs_desc} 
                          ${ODE_INCLUDE_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_dirs 
                          ${gazeboserver_link_dirs_desc} 
                          ${ODE_LIBRARY_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${ODE_LINK_LIBS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${ODE_LIBRARIES})
    APPEND_TO_CACHED_LIST(gazeboserver_ldflags
                          ${gazeboserver_ldflags_desc} 
                          ${ODE_LDFLAGS})
  ENDIF (NOT ODE_FOUND)

  # patched ode version with joint damping
  SET(ODE_WG_PATCHES_VERSION 0.11.1.68 CACHE INTERNAL "ODE version with joint damping" FORCE)
  pkg_check_modules(ODE_WG_PATCHES ode>=${ODE_WG_PATCHES_VERSION})
  IF (NOT ODE_WG_PATCHES_FOUND)
    SET (INCLUDE_ODE_JOINT_DAMPING FALSE CACHE BOOL "No support for ODE damping")
    SET (QUICKSTEP_EXPERIMENTAL FALSE CACHE BOOL "support for ODE quickstep experimental stuff")
  ELSE (NOT ODE_WG_PATCHES_FOUND)
    SET (INCLUDE_ODE_JOINT_DAMPING TRUE CACHE BOOL "Include support for ODE damping")
    SET (QUICKSTEP_EXPERIMENTAL TRUE CACHE BOOL "support for ODE quickstep experimental stuff")
  ENDIF (NOT ODE_WG_PATCHES_FOUND)

  #################################################
  # Find OGRE 
  pkg_check_modules(OGRE-RTShaderSystem OGRE-RTShaderSystem>=${MIN_OGRE_VERSION})
  if (OGRE-RTShaderSystem_FOUND)

    set(ogre_ldflags ${OGRE-RTShaderSystem_LDFLAGS})
    set(ogre_include_dirs ${OGRE-RTShaderSystem_INCLUDE_DIRS})
    set(ogre_library_dirs ${OGRE-RTShaderSystem_LIBRARY_DIRS})
    set(ogre_libraries ${OGRE-RTShaderSystem_LIBRARIES})
    set(ogre_cflags ${OGRE-RTShaderSystem_CFLAGS})

    set (INCLUDE_RTSHADER ON CACHE BOOL "Enable GPU shaders")

  else (OGRE-RTShaderSystem_FOUND)

    set (INCLUDE_RTSHADER OFF CACHE BOOL "Enable GPU shaders")

    pkg_check_modules(OGRE OGRE>=${MIN_OGRE_VERSION})
    if (NOT OGRE_FOUND)
      BUILD_ERROR("Missing: Ogre3d version >=${MIN_OGRE_VERSION}(http://www.orge3d.org)")
    else (NOT OGRE_FOUND)
      set(ogre_ldflags ${OGRE_LDFLAGS})
      set(ogre_include_dirs ${OGRE_INCLUDE_DIRS})
      set(ogre_library_dirs ${OGRE_LIBRARY_DIRS})
      set(ogre_libraries ${OGRE_LIBRARIES})
      set(ogre_cflags ${OGRE_CFLAGS})
    endif (NOT OGRE_FOUND)
      
  endif (OGRE-RTShaderSystem_FOUND)


  set (OGRE_LIBRARY_PATH ${ogre_library_dirs} CACHE INTERNAL "Ogre library path")

  APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                        ${gazeboserver_include_dirs_desc} 
                        ${ogre_include_dirs})
  APPEND_TO_CACHED_LIST(gazeboserver_link_dirs 
                        ${gazeboserver_link_dirs_desc} 
                        ${ogre_library_dirs})
  APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                        ${gazeboserver_link_libs_desc} 
                        ${ogre_link_libs})
  APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                        ${gazeboserver_link_libs_desc} 
                        ${ogre_libraries})
  APPEND_TO_CACHED_LIST(gazeboserver_ldflags 
                        ${gazeboserver_ldflags_desc} 
                        ${ogre_ldflags})
  APPEND_TO_CACHED_LIST(gazeboserver_cflags 
                        ${gazeboserver_cflags_desc} 
                        ${ogre_cflags})

  #################################################
  # Find GTK
  pkg_check_modules(GTK2 gtk+-2.0)
  IF (NOT GTK2_FOUND)
    BUILD_ERROR("Missing: gtk+-2.0")
  ELSE (NOT GTK2_FOUND)
    APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                          ${gazeboserver_include_dirs_desc} 
                          ${GTK2_INCLUDE_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_dirs 
                          ${gazeboserver_link_dirs_desc} 
                          ${GTK2_LIBRARY_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${GTK2_LINK_LIBS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${GTK2_LIBRARIES})
    APPEND_TO_CACHED_LIST(gazeboserver_ldflags 
                          ${gazeboserver_ldflags_desc} 
                          ${GTK2_LDFLAGS})
    APPEND_TO_CACHED_LIST(gazeboserver_cflags 
                          ${gazeboserver_cflags_desc} 
                          ${GTK2_CFLAGS})
  ENDIF (NOT GTK2_FOUND)


  #################################################
  # Find XML
  pkg_check_modules(XML libxml-2.0)
  IF (NOT XML_FOUND)
    BUILD_ERROR("Missing: libxml2(http://www.xmlsoft.org)")
  ELSE (NOT XML_FOUND)
    APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                          ${gazeboserver_include_dirs_desc} 
                          ${XML_INCLUDE_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_dirs 
                          ${gazeboserver_link_dirs_desc} 
                          ${XML_LIBRARY_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${XML_LINK_LIBS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${XML_LIBRARIES})
    APPEND_TO_CACHED_LIST(gazeboserver_ldflags 
                          ${gazeboserver_ldflags_desc} 
                          ${XML_LDFLAGS})
    APPEND_TO_CACHED_LIST(gazeboserver_cflags 
                          ${gazeboserver_cflags_desc} 
                          ${XML_CFLAGS})

  ENDIF (NOT XML_FOUND)


  ########################################
  # Find libXPM
  pkg_check_modules(XPM xpm)
  if (NOT XPM_FOUND)
    BUILD_ERROR("Missing: libXpm(http://cgit.freedesktop.org/xorg/lib/libXpm)")
  else (NOT XPM_FOUND)
    APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                          ${gazeboserver_include_dirs_desc} 
                          ${XPM_INCLUDE_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_dirs 
                          ${gazeboserver_link_dirs_desc} 
                          ${XPM_LIBRARY_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${XPM_LINK_LIBS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${XPM_LIBRARIES})
  endif (NOT XPM_FOUND)


  ########################################
  # Find OpenAL
  pkg_check_modules(OAL openal)
  if (NOT OAL_FOUND)
    BUILD_WARNING ("Openal not found. Audio capabilities will be disabled.")
  else (NOT OAL_FOUND)
    set (HAVE_OPENAL TRUE)
    APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                          ${gazeboserver_include_dirs_desc} 
                          ${OAL_INCLUDE_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_dirs 
                          ${gazeboserver_link_dirs_desc} 
                          ${OAL_LIBRARY_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${OAL_LINK_LIBS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${OAL_LIBRARIES})
  endif (NOT OAL_FOUND)

  ########################################
  # Find AV format
  pkg_check_modules(AVF libavformat)
  if (NOT AVF_FOUND)
    BUILD_WARNING ("libavformat not found. Audio capabilities will be disabled.")
  else (NOT AVF_FOUND)
    APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                          ${gazeboserver_include_dirs_desc} 
                          ${AVF_INCLUDE_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_dirs 
                          ${gazeboserver_link_dirs_desc} 
                          ${AVF_LIBRARY_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${AVF_LINK_LIBS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${AVF_LIBRARIES})
  endif (NOT AVF_FOUND)

  ########################################
  # Find avcodec
  pkg_check_modules(AVC libavcodec)
  if (NOT AVC_FOUND)
    BUILD_WARNING ("libavcodec not found. Audio capabilities will be disabled.")
  else (NOT AVC_FOUND)
    APPEND_TO_CACHED_LIST(gazeboserver_include_dirs 
                          ${gazeboserver_include_dirs_desc} 
                          ${AVC_INCLUDE_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_dirs 
                          ${gazeboserver_link_dirs_desc} 
                          ${AVC_LIBRARY_DIRS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${AVC_LINK_LIBS})
    APPEND_TO_CACHED_LIST(gazeboserver_link_libs 
                          ${gazeboserver_link_libs_desc} 
                          ${AVC_LIBRARIES})
  endif (NOT AVC_FOUND)

  IF (AVF_FOUND AND AVC_FOUND)
    SET (HAVE_FFMPEG TRUE)
  ENDIF (AVF_FOUND AND AVC_FOUND)

  ########################################
  # Find Player
  pkg_check_modules(PLAYER playercore>=3.0)
  if (NOT PLAYER_FOUND)
    set (INCLUDE_PLAYER OFF CACHE BOOL "Build gazebo plugin for player" FORCE)
    BUILD_WARNING ("Player not found, gazebo plugin for player will not be built.")
  else (NOT PLAYER_FOUND)
    set (INCLUDE_PLAYER ON CACHE BOOL "Build gazebo plugin for player" FORCE)
    set (PLAYER_INCLUDE_DIRS ${PLAYER_INCLUDE_DIRS} CACHE INTERNAL
         "Player include directory")
    set (PLAYER_LINK_DIRS ${PLAYER_LINK_DIRS} CACHE INTERNAL
         "Player link directory")
    set (PLAYER_LINK_LIBS ${PLAYER_LIBRARIES} CACHE INTERNAL
         "Player libraries")
  endif (NOT PLAYER_FOUND)

  ########################################
  # Find Websim
  pkg_check_modules(WEBSIM websim)
  if (NOT WEBSIM_FOUND)
    set (INCLUDE_WEBGAZEBO OFF CACHE BOOL "Build webgazebo" FORCE)
    BUILD_WARNING ("Websim not found. Webgazebo will not be built")
  else (NOT WEBSIM_FOUND)
    set (WEBSIM_INCLUDE_DIRS ${WEBSIM_INCLUDE_DIRS} CACHE INTERNAL
         "Websim include directory")
    set (WEBSIM_LINK_DIRS ${WEBSIM_LINK_DIRS} CACHE INTERNAL 
         "Websim link directory")
    set (WEBSIM_LINK_LIBS ${WEBSIM_LIBRARIES} CACHE INTERNAL
         "Websim libraries")
  endif (NOT WEBSIM_FOUND)

else (PKG_CONFIG_FOUND)
  set (BUILD_GAZEBO OFF CACHE INTERNAL "Build Gazebo" FORCE)
  message (FATAL_ERROR "\nError: pkg-config not found")
endif (PKG_CONFIG_FOUND)


########################################
# Find wxWidgets
find_package(wxWidgets)
if (NOT wxWidgets_FOUND)
    BUILD_ERROR ("Missing: wxWidgets(http://www.wxwidgets.org)")
endif (NOT wxWidgets_FOUND)


########################################
# Find Boost, if not specified manually
IF (NOT boost_include_dirs AND NOT boost_library_dirs AND NOT boost_libraries )

  # Clear some variables to ensure that the checks for boost are 
  # always run
  SET (Boost_THREAD_FOUND OFF CACHE INTERNAL "" FORCE)
  SET (Boost_SIGNALS_FOUND OFF CACHE INTERNAL "" FORCE)

  SET(Boost_ADDITIONAL_VERSIONS "1.35" "1.35.0" "1.36" "1.36.1" "1.37.0" "1.39.0" CACHE INTERNAL "Boost Additional versions" FORCE)
  INCLUDE (FindBoost)

  find_package( Boost ${MIN_BOOST_VERSION} REQUIRED thread signals regex)

  IF (NOT Boost_FOUND)
    SET (BUILD_GAZEBO OFF CACHE INTERNAL "Build Gazebo" FORCE)
    MESSAGE (FATAL_ERROR "Boost thread and signals not found. Please install Boost threads and signals version ${MIN_BOOST_VERSION} or higher.")
  ENDIF (NOT Boost_FOUND)

  SET (boost_include_dirs ${Boost_INCLUDE_DIRS} CACHE STRING 
    "Boost include paths. Use this to override automatic detection." FORCE)

  SET (boost_library_dirs ${Boost_LIBRARY_DIRS} CACHE STRING
    "Boost link dirs. Use this to override automatic detection." FORCE)

  LIST_TO_STRING(tmp "${Boost_LIBRARIES}")
  SET (boost_libraries ${tmp} CACHE STRING 
    "Boost libraries. Use this to override automatic detection." FORCE )

ENDIF (NOT boost_include_dirs AND NOT boost_library_dirs AND NOT boost_libraries ) 

STRING(REGEX REPLACE "(^| )-L" " " boost_library_dirs "${boost_library_dirs}")
STRING(REGEX REPLACE "(^| )-l" " " boost_libraries "${boost_libraries}")
#STRING(STRIP ${boost_library_dirs} boost_library_dirs)
#STRING(STRIP ${boost_libraries} boost_libraries)
STRING(REGEX REPLACE " " ";" boost_libraries "${boost_libraries}")

########################################
# Find avformat and avcodec
IF (HAVE_FFMPEG)
  SET (libavformat_search_path 
    /usr/include /usr/include/libavformat /usr/local/include 
    /usr/local/include/libavformat /usr/include/ffmpeg
  )
  
  SET (libavcodec_search_path 
    /usr/include /usr/include/libavcodec /usr/local/include 
    /usr/local/include/libavcodec /usr/include/ffmpeg
  )
  
  FIND_PATH(LIBAVFORMAT_PATH avformat.h ${libavformat_search_path})
  IF (NOT LIBAVFORMAT_PATH)
    MESSAGE (STATUS "Looking for avformat.h - not found")
    BUILD_WARNING ("avformat.h not found. audio/video will not be built")
    SET (LIBAVFORMAT_PATH /usr/include)
  ELSE (NOT LIBAVFORMAT_PATH)
    MESSAGE (STATUS "Looking for avformat.h - found")
  ENDIF (NOT LIBAVFORMAT_PATH)

  FIND_PATH(LIBAVCODEC_PATH avcodec.h ${libavcodec_search_path})
  IF (NOT LIBAVCODEC_PATH)
    MESSAGE (STATUS "Looking for avcodec.h - not found")
    BUILD_WARNING ("avcodec.h not found. audio/video will not be built")
    SET (LIBAVCODEC_PATH /usr/include)
  ELSE (NOT LIBAVCODEC_PATH)
    MESSAGE (STATUS "Looking for avcodec.h - found")
  ENDIF (NOT LIBAVCODEC_PATH)

ELSE (HAVE_FFMPEG)
  SET (LIBAVFORMAT_PATH /usr/include)
  SET (LIBAVCODEC_PATH /usr/include)
ENDIF (HAVE_FFMPEG)

########################################
# Find libevent
SET (libevent_search_path /usr/include /usr/local/include)
FIND_PATH(LIBEVENT_PATH event.h ${libevent_search_path})
IF (NOT LIBEVENT_PATH)
  MESSAGE (STATUS "Looking for event.h - not found")
  BUILD_WARNING ("event.h not found. webgazebo will not be built")
  SET (INCLUDE_WEBGAZEBO OFF CACHE BOOL "Found libevent" FORCE)
ELSE (NOT LIBEVENT_PATH)
  MESSAGE (STATUS "Looking for event.h - found")
ENDIF (NOT LIBEVENT_PATH)

########################################
# Find profiler library, optional
FIND_LIBRARY(PROFILER "profiler")
IF (PROFILER)
  SET (CMAKE_LINK_FLAGS_PROFILE "${CMAKE_LINK_FLAGS_PROFILE} -lprofiler" 
       CACHE INTERNAL "Link flags for profile" FORCE)
ENDIF (PROFILER)

########################################
# Find tcmalloc library, optional
FIND_LIBRARY(TCMALLOC "tcmalloc")
IF (TCMALLOC)
  SET (CMAKE_LINK_FLAGS_PROFILE "${CMAKE_LINK_FLAGS_PROFILE} -ltcmalloc" 
       CACHE INTERNAL "Link flags for profile" FORCE)
ENDIF (TCMALLOC)

########################################
# Find libtool
FIND_PATH(libtool_include_dir ltdl.h /usr/include /usr/local/include)
IF (NOT libtool_include_dir)
  MESSAGE (STATUS "Looking for ltdl.h - not found")
  BUILD_WARNING ("ltdl.h not found, plugins will not be supported.")
  SET (libtool_include_dir /usr/include)
ELSE (NOT libtool_include_dir)
  MESSAGE (STATUS "Looking for ltdl.h - found")
ENDIF (NOT libtool_include_dir)

FIND_LIBRARY(libtool_library ltdl /usr/lib /usr/local/lib)
IF (NOT libtool_library)
  MESSAGE (STATUS "Looking for libltdl - not found")

ELSE (NOT libtool_library)
  MESSAGE (STATUS "Looking for libltdl - found")
ENDIF (NOT libtool_library)

IF (libtool_library AND libtool_include_dir)
  SET (HAVE_LTDL TRUE)
ENDIF (libtool_library AND libtool_include_dir)


########################################
# Find libyaml
#
find_path(yaml_include yaml.h ${yaml_include} ENV CPATH)
if (yaml_include)
  message (STATUS "Looking for yaml.h - found")
else ()
  message (STATUS "Looking for yaml.h - not found")
endif ()

find_library(libyaml yaml ENV LD_LIBRARY_PATH)
if (libyaml)
  message (STATUS "Looking for libyaml - found")
else ()
  message (STATUS "Looking for libyaml - not found")
endif ()

if (NOT libyaml OR NOT yaml_include)
  BUILD_ERROR("Missing: yaml(http://www.yaml.org)")
endif (NOT libyaml OR NOT yaml_include)

########################################
# Find libdl
find_path(libdl_include_dir dlfcn.h /usr/include /usr/local/include)
if (NOT libdl_include_dir)
  message (STATUS "Looking for dlfcn.h - not found")
  BUILD_WARNING ("dlfcn.h not found, plugins will not be supported.")
  set (libdl_include_dir /usr/include)
else (NOT libdl_include_dir)
  message (STATUS "Looking for dlfcn.h - found")
endif (NOT libdl_include_dir)

find_library(libdl_library dl /usr/lib /usr/local/lib)
if (NOT libdl_library)
  message (STATUS "Looking for libdl - not found")
  BUILD_WARNING ("libdl not found, plugins will not be supported.")
else (NOT libdl_library)
  message (STATUS "Looking for libdl - found")
endif (NOT libdl_library)

if (libdl_library AND libdl_include_dir)
  SET (HAVE_DL TRUE)
else (libdl_library AND libdl_include_dir)
  SET (HAVE_DL FALSE)
endif (libdl_library AND libdl_include_dir)

########################################
# Find assimp
if (NOT assimp_include_dirs AND NOT assimp_library_dirs AND NOT assimp_libraries )

  find_path(assimp_include_dir assimp/assimp.hpp ${assimp_include_dirs} ENV CPATH)
  
  if (NOT assimp_include_dir)
    message (STATUS "Looking for assimp/assimp.hpp - not found.")
    set (assimp_include_dirs /usr/include CACHE STRING
      "Assimp include paths. Use this to override automatic detection.")
  else (NOT assimp_include_dir)
    message (STATUS "Looking for assimp/assimp.hpp - found")
    set (assim_include_dirs ${assimp_include_dir} CACHE STRING
      "Assimp include paths. Use this to override automatic detection.")
  endif (NOT assimp_include_dir)
  
  find_library(assimp_library assimp ENV LD_LIBRARY_PATH)
  
  if (assimp_library)
    message (STATUS "Looking for libassimp - found")
    APPEND_TO_CACHED_LIST(assimp_libraries
                          "Assimp libraries Use this to override automatic detection."
                          ${assimp_library})
  endif (assimp_library)
 
  if (NOT assimp_include_dir OR NOT assimp_library)
    BUILD_ERROR("Missing: Assimp(http://assimp.sourceforge.net)")
  endif (NOT assimp_include_dir OR NOT assimp_library)

endif (NOT assimp_include_dirs AND NOT assimp_library_dirs AND NOT assimp_libraries )

########################################
# Find bullet
if (NOT bullet_include_dirs AND NOT bullet_library_dirs AND NOT bullet_lflags )

  find_path(bullet_include_dir btBulletDynamicsCommon.h ${bullet_include_dirs} ENV CPATH)
  
  if (NOT bullet_include_dir)
    message (STATUS "Looking for btBulletDynamicsCommon.h - not found.")
    set (bullet_include_dirs /usr/include CACHE STRING
      "bullet include paths. Use this to override automatic detection.")
  else (NOT bullet_include_dir)
    message (STATUS "Looking for btBulletDynamicsCommon.h - found")
    set (bullet_include_dirs ${bullet_include_dir} CACHE STRING
      "bullet include paths. Use this to override automatic detection.")
  endif (NOT bullet_include_dir)
  
  find_library(bullet_math_library LinearMath ENV LD_LIBRARY_PATH)
  find_library(bullet_collision_library BulletCollision ENV LD_LIBRARY_PATH)
  find_library(bullet_softbody_library BulletSoftBody  ENV LD_LIBRARY_PATH)
  find_library(bullet_dynamics_library BulletDynamics ENV LD_LIBRARY_PATH)
  
  if (NOT bullet_dynamics_library)
    message (STATUS "Looking for libBulletDynamics - not found.")
  else (NOT bullet_dynamics_library)
    message (STATUS "Looking for libBulletDynamics - found")
    APPEND_TO_CACHED_List(bullet_lflags "bullet libraries Use this to override automatic detection." -lBulletDynamics)
  endif (NOT bullet_dynamics_library)

  if (NOT bullet_collision_library)
    message (STATUS "Looking for libBulletCollision - not found.")
  else (NOT bullet_collision_library)
    message (STATUS "Looking for libBulletCollision - found")
    APPEND_TO_CACHED_List(bullet_lflags "bullet libraries Use this to override automatic detection." -lBulletCollision)
  endif (NOT bullet_collision_library)
  
  if (NOT bullet_math_library)
    message (STATUS "Looking for libLinearMath - not found.")
  else (NOT bullet_math_library)
    message (STATUS "Looking for libLinearMath - found")
    APPEND_TO_CACHED_List(bullet_lflags "bullet libraries Use this to override automatic detection." -lLinearMath)
  endif (NOT bullet_math_library)

  if (NOT bullet_softbody_library)
    message (STATUS "Looking for libBulletSoftBody - not found.")
  else (NOT bullet_softbody_library)
    message (STATUS "Looking for libBulletSoftBody - found")
    APPEND_TO_CACHED_List(bullet_lflags "bullet libraries Use this to override automatic detection." -lBulletSoftBody)
  endif (NOT bullet_softbody_library)

  APPEND_TO_CACHED_LIST(gazeboserver_ldflags
                        ${gazeboserver_ldflags_desc} 
                        ${bullet_lflags})

  if (NOT bullet_include_dir OR NOT bullet_dynamics_library)
    set (INCLUDE_BULLET OFF CACHE BOOL "Include Bullet" FORCE)
  else (NOT bullet_include_dir OR NOT bullet_dynamics_library)
    set (INCLUDE_BULLET ON CACHE BOOL "Include Bullet" FORCE)
  endif (NOT bullet_include_dir OR NOT bullet_dynamics_library)

else (NOT bullet_include_dirs AND NOT bullet_library_dirs AND NOT bullet_lflags )
  set (INCLUDE_BULLET ON CACHE BOOL "Include Bullet" FORCE)
endif (NOT bullet_include_dirs AND NOT bullet_library_dirs AND NOT bullet_lflags )

# Check to make sure bullet was compiled with DOUBLE_PRECISION
if (INCLUDE_BULLET)
  set (check_bullet_code "#include <btBulletDynamicsCommon.h> 
int main() { btRigidBody body(0,NULL, NULL, btVector3(0,0,0)); return 0; }")

  set (CMAKE_REQUIRED_DEFINITIONS "-DBT_USE_DOUBLE_PRECISION")
  STRING (REPLACE " " ";" bullet_include_dirs_split "${bullet_include_dirs}") #for cmake 2.4-7
  STRING (REPLACE " " ";" bullet_library_dirs_split "${bullet_library_dirs}") #for cmake 2.4-7
  set( CMAKE_REQUIRED_INCLUDES ${bullet_include_dirs_split} )
  set (CMAKE_REQUIRED_LIBRARIES BulletDynamics BulletCollision LinearMath)
  set( CMAKE_REQUIRED_FLAGS  ${bullet_lflags} )
  CHECK_CXX_SOURCE_COMPILES ("${check_bullet_code}" BULLET_DOUBLE_PRECISION)
  set (CMAKE_REQUIRED_LIBRARIES)
  set (CMAKE_REQUIRED_DEFINITIONS)
  set( CMAKE_REQUIRED_INCLUDES)
  set( CMAKE_REQUIRED_FLAGS)

  if (NOT BULLET_DOUBLE_PRECISION)
    BUILD_ERROR("Dependency: bullet was not compiled to use double precision.")
    set (INCLUDE_BULLET OFF CACHE BOOL "Include Bullet" FORCE)
  endif (NOT BULLET_DOUBLE_PRECISION)
endif (INCLUDE_BULLET)

########################################
# Find parallel_quickstep
STRING(REPLACE " " ";" parallel_quickstep_include_dirs_split "${parallel_quickstep_include_dirs}")
STRING(REPLACE " " ";" parallel_quickstep_library_dirs_split "${parallel_quickstep_library_dirs}")
set( CMAKE_REQUIRED_INCLUDES ${parallel_quickstep_include_dirs_split} )
set( CMAKE_REQUIRED_LIBRARIES ${parallel_quickstep_library} )
set( CMAKE_REQUIRED_FLAGS  ${parallel_quickstep_lflags} )
 
#STRING(REPLACE " " "/parallel_quickstep " parallel_quickstep_include_dirs_tmp "${parallel_quickstep_include_dirs}")
find_path(parallel_quickstep_include_found parallel_quickstep/parallel_quickstep.h '${parallel_quickstep_include_dirs}')
if (NOT parallel_quickstep_include_found)
  message (STATUS "Looking for parallel_quickstep.h in ${parallel_quickstep_include_dirs} - not found")
  BUILD_WARNING ("parallel_quickstep.h not found, plugins will not be supported.")
else (NOT parallel_quickstep_include_found)
  message (STATUS "Looking for parallel_quickstep.h - found")
endif (NOT parallel_quickstep_include_found)

find_library(parallel_quickstep_library_found parallel_quickstep ${parallel_quickstep_library_dirs})
if (NOT parallel_quickstep_library_found)
  message (STATUS "Looking for libparallel_quickstep.so in ${parallel_quickstep_library_dirs} - not found")
  BUILD_WARNING ("libparallel_quickstep.so not found, parallel_quickstep will not be supported.")
else (NOT parallel_quickstep_library_found)
  message (STATUS "Looking for libparallel_quickstep.so - found")
endif (NOT parallel_quickstep_library_found)

if (parallel_quickstep_library_found AND parallel_quickstep_include_found)

  SET (PARALLEL_QUICKSTEP ON CACHE BOOL "Build gazebo with parallel_quickstep support" FORCE)

else (parallel_quickstep_library_found AND parallel_quickstep_include_found)

  SET (PARALLEL_QUICKSTEP OFF CACHE BOOL "Build gazebo without parallel_quickstep support" FORCE)

endif (parallel_quickstep_library_found AND parallel_quickstep_include_found)

