cmake_minimum_required (VERSION 3.0)

# ~~~
# you might need to change CMAKE_MODULE_PATH
# can also be done with ccmake
# set (CUSTOM_MODULE_PATH "/opt/local/share/cmake-3.0/Modules")
# set (CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CUSTOM_MODULE_PATH})
# ~~~

find_package (Elektra REQUIRED)

if (NOT KDB)
	set (KDB kdb)
endif (NOT KDB)

if (ELEKTRA_FOUND)
	message (STATUS "Elektra ${ELEKTRA_VERSION} found")

	include_directories (${Elektra_INCLUDE_DIRS} ${CMAKE_CURRENT_BINARY_DIR})

	add_custom_command (OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/genelektra.c ${CMAKE_CURRENT_BINARY_DIR}/genelektra.h
			    COMMAND ${KDB}
				    ARGS
				    gen
				    -F
				    "ni=${CMAKE_CURRENT_SOURCE_DIR}/../spec.ini"
				    elektra
				    "spec/sw/example/tree/#0/current"
				    "genelektra"
			    MAIN_DEPENDENCY ../spec.ini
			    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

	add_executable (application ../src/application.c ${CMAKE_CURRENT_BINARY_DIR}/genelektra.c)
	target_link_libraries (application ${ElektraCodegen_LIBRARIES})

	if (CMAKE_VERSION VERSION_LESS "3.1")
		target_compile_options (application PRIVATE "-std=c99")
	else ()
		set_property (TARGET application PROPERTY C_STANDARD 99)
	endif ()
else (ELEKTRA_FOUND)
	message (FATAL_ERROR "Elektra not found")
endif (ELEKTRA_FOUND)
