cmake_minimum_required(VERSION 3.18.1)

project("arcade_runner")

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Alineación ELF a 16 KB (dispositivos Android / Google TV con page size 16 KB).
set(CMAKE_SHARED_LINKER_FLAGS
    "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384"
)

add_library(
        arcade_runner
        SHARED
        arcade_runner.cpp
)

find_library(
        log-lib
        log
)

find_library(
        android-lib
        android
)

find_library(
        aaudio-lib
        aaudio
)

target_link_libraries(
        arcade_runner
        ${log-lib}
        ${android-lib}
        ${aaudio-lib}
)
