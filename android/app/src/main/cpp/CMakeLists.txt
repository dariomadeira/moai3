cmake_minimum_required(VERSION 3.18.1)

project("arcade_runner")

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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
