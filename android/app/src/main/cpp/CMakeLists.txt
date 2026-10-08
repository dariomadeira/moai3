cmake_minimum_required(VERSION 3.18.1)

project("arcade_runner")

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

target_link_libraries(
        arcade_runner
        ${log-lib}
        ${android-lib}
)
