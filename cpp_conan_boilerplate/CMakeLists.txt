cmake_minimum_required(VERSION 3.26)
project(${PROJECT_NAME} LANGUAGES CXX) # change ${PROJECT_NAME} to actual projet
# name only in project()

# standart
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# export compile commands for vscode/nvim
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
# configurations
set(CMAKE_CONFIGURATION_TYPES
    "Debug;Release;RelWithDebInfo;MinSizeRel"
    CACHE STRING "" FORCE)

# lld
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=mold")

# lto
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)

# find include-what-you-use
find_program(IWYU_PROGRAM NAMES include-what-you-use
)# https://github.com/include-what-you-use/include-what-you-use
if(IWYU_PROGRAM)
  set(CMAKE_CXX_INCLUDE_WHAT_YOU_USE ${IWYU_PROGRAM})
endif()

# doxygen
if(DOCS)
  add_subdirectory(docs)
endif()

# caching on ci
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ${CCACHE_PROGRAM})
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ${CCACHE_PROGRAM})
endif()

# Function to copy target after build
function(copy_after_build TARGET_NAME)
  set(DESTDIR ${CMAKE_CURRENT_LIST_DIR}/bin/)
  file(MAKE_DIRECTORY ${DESTDIR})
  # Copy binary file to <CMakeLists.txt didctory>./bin after target is compiled.
  add_custom_command(
    TARGET ${TARGET_NAME}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${TARGET_NAME}> ${DESTDIR})
endfunction()

# Find packages conan
find_package(Boost REQUIRED)
find_package(glfw3 REQUIRED)
find_package(glm REQUIRED)

# Target Configurations
file(GLOB SOURCE_FILES src/*.cpp)
add_executable(${PROJECT_NAME} ${SOURCE_FILES})

# add include forlder with header and compile options
target_include_directories(${PROJECT_NAME} PRIVATE include)

# compile options for debug and release
target_compile_options(
  ${PROJECT_NAME}
  PRIVATE $<$<CONFIG:DEBUG>:-Wall
          -Wextra
          -Wpedantic
          -fsanitize=address
          -fsanitize=undefined
          -fsanitize=thread
          -fPIE
          -pie
          -fno-omit-frame-pointer
          -g>
          $<$<CONFIG:RELEASE>:-O3
          -flto
          -Wall>)

# add subdirectory for libraries
add_subdirectory(lib)

# link main project with libraries
target_link_libraries(${PROJECT_NAME} glm::glm)
target_link_libraries(${PROJECT_NAME} glfw)

# boost
if(NOT WIN32)
  target_link_libraries(${PROJECT_NAME} boost::system pthread)
else()
  # Windows WIN32 API
  target_link_libraries(${PROJECT_NAME} boost::system)
endif()

find_program(CLANG_FORMAT "clang-format")
if(CLANG_FORMAT)
  add_custom_target(format COMMAND ${CLANG_FORMAT} -i ${SOURCE_FILES})
endif()

find_program(CLANG_TIDY "clang-tidy")
if(CLANG_TIDY)
  set(CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY}")
endif()

find_program(CPPCHECK "cppcheck")
if(CPPCHECK)
  set(CMAKE_CXX_CPPCHECK "${CPPCHECK}")
endif()

#Use in graphics projects
############## Build SHADERS #######################
find_program(
  GLSL_VALIDATOR glslangValidator
  HINTS ${Vulkan_GLSLANG_VALIDATOR_EXECUTABLE}
        /usr/bin
        /usr/local/bin
        ${VULKAN_SDK_PATH}/Bin
        ${VULKAN_SDK_PATH}/Bin32
        $ENV{VULKAN_SDK}/Bin/
        $ENV{VULKAN_SDK}/Bin32/)

# get all .vert and .frag files in shaders directory
file(GLOB_RECURSE GLSL_SOURCE_FILES "${PROJECT_SOURCE_DIR}/shaders/*.frag"
     "${PROJECT_SOURCE_DIR}/shaders/*.vert")

foreach(GLSL ${GLSL_SOURCE_FILES})
  get_filename_component(FILE_NAME ${GLSL} NAME)
  set(SPIRV "${PROJECT_SOURCE_DIR}/shaders/${FILE_NAME}.spv")
  add_custom_command(
    OUTPUT ${SPIRV}
    COMMAND ${GLSL_VALIDATOR} -V ${GLSL} -o ${SPIRV}
    DEPENDS ${GLSL})
  list(APPEND SPIRV_BINARY_FILES ${SPIRV})
endforeach(GLSL)

add_custom_target(Shaders DEPENDS ${SPIRV_BINARY_FILES})
# add shaders as dependency to the main target
add_dependencies(${PROJECT_NAME} Shaders)
