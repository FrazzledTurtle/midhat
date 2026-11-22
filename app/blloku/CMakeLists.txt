cmake_minimum_required(VERSION 3.21)
project(blloku VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick)
qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

qt_add_executable(blloku
  src/main.cpp
  src/blocks.h src/blocks.cpp
  src/page.h src/page.cpp
  src/highlighter.h src/highlighter.cpp
  src/ink.h src/ink.cpp
  src/library.h src/library.cpp
)
# No ahead-of-time QML: it links Qt private API, and [midhat] has no rebuild on Qt updates.
qt_add_qml_module(blloku URI Blloku VERSION 1.0 NO_CACHEGEN QML_FILES qml/Main.qml qml/Paper.qml qml/Library.qml)
target_include_directories(blloku PRIVATE src)
target_link_libraries(blloku PRIVATE Qt6::Core Qt6::Gui Qt6::Quick)

install(TARGETS blloku RUNTIME DESTINATION bin)
install(FILES org.midhat.Blloku.desktop DESTINATION share/applications)

enable_testing()
add_executable(blocks_test tests/blocks_test.cpp src/blocks.cpp)
target_include_directories(blocks_test PRIVATE src)
target_link_libraries(blocks_test PRIVATE Qt6::Core)
add_test(NAME blocks COMMAND blocks_test)
add_executable(page_test tests/page_test.cpp src/page.h src/page.cpp src/blocks.cpp)
target_include_directories(page_test PRIVATE src)
target_link_libraries(page_test PRIVATE Qt6::Core)
add_test(NAME page COMMAND page_test)
add_executable(ink_test tests/ink_test.cpp src/ink.h src/ink.cpp)
target_include_directories(ink_test PRIVATE src)
target_link_libraries(ink_test PRIVATE Qt6::Core Qt6::Gui Qt6::Quick)
add_test(NAME ink COMMAND ink_test)
add_executable(library_test tests/library_test.cpp src/library.h src/library.cpp src/page.h src/page.cpp src/blocks.cpp)
target_include_directories(library_test PRIVATE src)
target_link_libraries(library_test PRIVATE Qt6::Core)
add_test(NAME library COMMAND library_test)
