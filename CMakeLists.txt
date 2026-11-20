cmake_minimum_required(VERSION 3.16)
project(WatchBoard VERSION 0.45.11 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Quick QuickControls2 SerialPort)
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)
qt_policy(SET QTP0005 NEW)   # DEPENDENCIES TARGET Mahina

# ── Mahina (QML component library) ──────────────────────────────────────────
# Fetched from GitHub at a pinned tag. To build against a local checkout
# (e.g. while changing Mahina itself), configure with:
#   -DFETCHCONTENT_SOURCE_DIR_MAHINA=/path/to/mahina
include(FetchContent)
FetchContent_Declare(Mahina
    GIT_REPOSITORY https://github.com/ajunior/mahina.git
    GIT_TAG        v0.45.27
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(Mahina)

qt_add_executable(watchboard
    src/main.cpp
    src/backend/SerialManager.h
    src/backend/SerialManager.cpp
    src/backend/DeviceProtocol.h
    src/backend/DeviceProtocol.cpp
    src/backend/PinModel.h
    src/backend/PinModel.cpp
    src/backend/WatchModel.h
    src/backend/WatchModel.cpp
    src/backend/BoardInfo.h
    src/backend/BoardInfo.cpp
    src/backend/DeviceController.h
    src/backend/DeviceController.cpp
    src/backend/BoardProfile.h
    src/backend/BoardProfile.cpp
    src/backend/SerialLogModel.h
    src/backend/SerialLogModel.cpp
)

qt_add_qml_module(watchboard
    URI WatchBoard
    VERSION 1.0
    DEPENDENCIES TARGET Mahina
    QML_FILES
        src/qml/main.qml
        src/qml/format.js
        src/qml/components/ConnectionBar.qml
        src/qml/components/PinGrid.qml
        src/qml/components/PinItem.qml
        src/qml/components/Pill.qml
        src/qml/components/Logo.qml
        src/qml/components/AboutDialog.qml
        src/qml/components/SerialMonitor.qml
        src/qml/components/WatchPlotter.qml
        src/qml/components/HomePanel.qml
        src/qml/components/VariablesPanel.qml
    RESOURCES
        assets/logo.svg
)

# Shown in the About dialog. Mahina's version is read from its own project(),
# so it stays right when FETCHCONTENT_SOURCE_DIR_MAHINA points at a local tree.
get_directory_property(MAHINA_VERSION DIRECTORY "${mahina_SOURCE_DIR}" DEFINITION PROJECT_VERSION)
set(WATCHBOARD_REPO_URL "https://github.com/ajunior/watchboard" CACHE STRING "Project home, linked from the About dialog")

target_compile_definitions(watchboard PRIVATE
    WATCHBOARD_VERSION="${PROJECT_VERSION}"
    MAHINA_VERSION="${MAHINA_VERSION}"
    WATCHBOARD_REPO_URL="${WATCHBOARD_REPO_URL}"
)

target_link_libraries(watchboard PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::SerialPort
    Mahina
    Mahinaplugin
    Mahinaplugin_init
)

set_target_properties(watchboard PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
)

# ── macOS bundle metadata ─────────────────────────────────────────────────────
# The bundle is WatchBoard.app (what Finder and /Applications show); the binary
# keeps the lowercase name everywhere else. The icon has to be a real file in
# Contents/Resources, so it is generated from the PNG master and placed there.
if(APPLE)
    set_target_properties(watchboard PROPERTIES OUTPUT_NAME "WatchBoard")
    configure_file(packaging/macos/Info.plist.in ${CMAKE_BINARY_DIR}/Info.plist @ONLY)

    add_custom_command(
        OUTPUT  ${CMAKE_BINARY_DIR}/watchboard.icns
        COMMAND bash ${CMAKE_CURRENT_SOURCE_DIR}/packaging/macos/make-icns.sh
                     ${CMAKE_CURRENT_SOURCE_DIR}/assets/watchboard.png
                     ${CMAKE_BINARY_DIR}/watchboard.icns
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/assets/watchboard.png
                ${CMAKE_CURRENT_SOURCE_DIR}/packaging/macos/make-icns.sh
        COMMENT "Generating watchboard.icns"
        VERBATIM
    )
    target_sources(watchboard PRIVATE ${CMAKE_BINARY_DIR}/watchboard.icns)
    set_source_files_properties(${CMAKE_BINARY_DIR}/watchboard.icns PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)

    set_target_properties(watchboard PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_BINARY_DIR}/Info.plist")
endif()

# ── Windows: embedded version info and icon ───────────────────────────────────
# The icon is copied next to the generated .rc so the script names it with no
# path: rc.exe treats a backslash inside a quoted path as an escape.
if(WIN32)
    configure_file(assets/watchboard.ico ${CMAKE_BINARY_DIR}/watchboard.ico COPYONLY)
    configure_file(packaging/windows/watchboard.rc.in ${CMAKE_BINARY_DIR}/watchboard.rc @ONLY)
    target_sources(watchboard PRIVATE ${CMAKE_BINARY_DIR}/watchboard.rc)
endif()
