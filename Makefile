.DELETE_ON_ERROR:
.SUFFIXES:

# Makefile
# Written by Leon Krieg <info@madcow.dev>

# Please run ./configure once before invoking make to ensure the environment is
# properly set up. The build system will by default compile any C and C++ source
# files found in SRCDIR for both Linux and Windows and then link the resulting
# object files with the appropriate linker. All temporary build files are placed
# in TMPDIR. The release target will generate tarballs containing the binaries,
# assets from DATADIR and the gcc runtime libraries required for windows. If
# there are any unit-tests found in TESTDIR, they will be compiled for both
# operating systems with system-specific unit-tests expected in TESTDIR/SYSDIR.
# Checks will be skipped if no such files are found. In total this creates four
# separate builds: linux, linux-testing, win32 and win32-testing using different
# compilers depending on the input file.

ifeq ($(wildcard .settings.mk),)
$(error Please run ./configure first)
endif

# ==============================================================================
# PROJECT SETTINGS
# ==============================================================================

# PROJECT       Project identifier.
# VERBOSE       Show full command text? Boolean.
# SRCDIR        C and C++ source files directory.
# SYSDIR        Platform-dependend source files directory.
# BINDIR        Binaries and shared libraries output directory.
# DATADIR       Optional data files to be copied into the tarball.
# TESTDIR       Optional unit tests for regular and system sources.
# TMPDIR        Temporary object and header dependencies directory.
# ENTRY         File in SRCDIR which declares the main() function.
# LINUX         Linux subdirectory of SYSDIR, tarball suffix, etc.
# WIN32         Win32 subdirectory of SYSDIR, tarball suffix, etc.

PROJECT         := template
VERBOSE         := false
SRCDIR          := src
SYSDIR          := system
BINDIR          := bin
DATADIR         := data
TESTDIR         := tests
TMPDIR          := build
ENTRY           := main.c
LINUX           := linux
WIN32           := win32

# ==============================================================================
# TOOLCHAIN GENERAL SETTINGS
# ==============================================================================

# WFLAGS        Compiler error flags.
# CPPFLAGS      Shared preprocessor flags.
# CFLAGS        Compiler flags for C including error flags.
# CXXFLAGS      Compiler flags for C++ including error flags.
# MDFLAGS       Automatic preprocessor header dependency flags.
# LDFLAGS       Linker settings passed to compiler - not ld.
# LDLIBS        Linker library imports.
# POSIXDEF      POSIX version on linux.

WFLAGS          := -Wall -Wextra -Werror
CPPFLAGS        := -DDEBUG -I$(SRCDIR)
CFLAGS          := -std=c99 -pedantic $(WFLAGS)
CXXFLAGS        := -std=c++98 -pedantic $(WFLAGS)
MDFLAGS          = -MM -MT $(@:.d=.o)
LDFLAGS         :=
LDLIBS          :=
POSIXDEF        := 200112L
MKDIR           ?= mkdir -p
RM              ?= rm -f
TAR             ?= tar

# ==============================================================================
# TOOLCHAIN SYSTEM-SPECIFIC SETTINGS
# ==============================================================================

# Note we're adding the console subsystem flag to windows applications because
# otherwise the process will immediately detach from the console meaning we have
# to allocate a new console. This opens a separate window making it miserable to
# use from the shell and also requires us to set up the stream descriptors. This
# is more work than jumping to GUI mode from a console application.

CC_LINUX           ?= x86_64-linux-gnu-gcc
CC_WIN32           ?= x86_64-w64-mingw32-gcc
CXX_LINUX          ?= x86_64-linux-gnu-g++
CXX_WIN32          ?= x86_64-w64-mingw32-g++
LD_LINUX           := $(CXX_LINUX)
LD_WIN32           := $(CXX_WIN32)
TARGET_LINUX       := $(BINDIR)/$(LINUX)/$(PROJECT)
TARGET_WIN32       := $(BINDIR)/$(WIN32)/$(PROJECT).exe
TARGET_LINUX_TEST  := $(BINDIR)/$(LINUX)/$(PROJECT)-test
TARGET_WIN32_TEST  := $(BINDIR)/$(WIN32)/$(PROJECT)-test.exe
RELEASE_LINUX      := $(BINDIR)/$(PROJECT)-$(LINUX)_64.tar
RELEASE_WIN32      := $(BINDIR)/$(PROJECT)-$(WIN32)_64.tar
CPPFLAGS_LINUX     := $(CPPFLAGS) -DLINUX -D_POSIX_C_SOURCE=$(POSIXDEF)
CPPFLAGS_WIN32     := $(CPPFLAGS) -DWIN32 -DWIN32_LEAN_AND_MEAN
CFLAGS_LINUX       := $(CFLAGS)
CFLAGS_WIN32       := $(CFLAGS)
CXXFLAGS_LINUX     := $(CXXFLAGS)
CXXFLAGS_WIN32     := $(CXXFLAGS)
LDFLAGS_LINUX      := $(LDFLAGS)
LDFLAGS_WIN32      := $(LDFLAGS) "-Wl,--subsystem,console"
LDLIBS_LINUX       := $(LDLIBS)
LDLIBS_WIN32       := $(LDLIBS) -lgdi32
MDFLAGS_LINUX       = $(MDFLAGS)
MDFLAGS_WIN32       = $(MDFLAGS)

# ==============================================================================
# HELPER MACROS
# ==============================================================================

# These helper macros are here to reduce the amount of boilerplace code for the
# following rules below. They are simple variable substitutions to mostly select
# tools and flags for the target operating system. Sorry about the absolute
# illegibility of those defines as they almost look like ancient M4 macros.

define REPLACE_EXT
$(patsubst %.cpp,$(TMPDIR)/$(2)/%.$(1),\
$($(3):%.c=$(TMPDIR)/$(2)/%.$(1)))
endef

define FIND
$(shell find "$(1)" -type f \( -name "*.c" -o \
-name '*.cpp' \) -print 2>/dev/null)
endef

define FIND_EXCLUDE
$(shell find "$(1)" -type d -name "$(2)" -prune -o -type f \
\( -name "*.c" -o -name '*.cpp' \) -print 2>/dev/null)
endef

define FIND_TMPDIRS
$(patsubst %,$(TMPDIR)/$(2)/%,\
$(shell find $(1) -type d 2>/dev/null))
endef

define LINK
$(E) "[BIN] $@"; $(MKDIR) $(@D)
$(Q) $(LD_$(1)) -o $@ $(LDFLAGS_$(1)) $($(2)) $(LDLIBS_$(1))
endef

define COMPILE
$(E) "[OBJ] $@"
$(Q) $($(1)_$(2)) -c -o $@ $($(3)_$(2)) $(CPPFLAGS_$(2)) $<
endef

define MAKEDEP
$(E) "[DEP] $@"
$(Q) $($(1)_$(2)) -c -o $@ $(CPPFLAGS_$(2)) $(MDFLAGS_$(2)) $<
endef

# ==============================================================================
# SOURCE FILE LISTS
# ==============================================================================

# Automatically scanning for required sources instead of having to list them all
# by hand is my primary reason for preferring the GNU make implementation over
# the POSIX standard. We can't redeclare the entry symbol for unit testing so
# we have to filter out the main function. We could define a preprocessor symbol
# when testing but this clutters the codebase so we rather remove the file from
# the list of objects when linking the unit tests.

FILES               := $(call FIND_EXCLUDE,$(SRCDIR),$(SYSDIR))
FILES_LINUX         := $(FILES) $(call FIND,$(SRCDIR)/$(SYSDIR)/$(LINUX))
FILES_WIN32         := $(FILES) $(call FIND,$(SRCDIR)/$(SYSDIR)/$(WIN32))
FILES_TESTS         := $(call FIND_EXCLUDE,$(TESTDIR),$(SYSDIR))
FILES_TESTS_LINUX   := $(FILES_TESTS) $(call FIND,$(TESTDIR)/$(SYSDIR)/$(LINUX))
FILES_TESTS_WIN32   := $(FILES_TESTS) $(call FIND,$(TESTDIR)/$(SYSDIR)/$(WIN32))
FILES_LINUX_NOMAIN  := $(filter-out $(SRCDIR)/$(ENTRY),$(FILES_LINUX))
FILES_WIN32_NOMAIN  := $(filter-out $(SRCDIR)/$(ENTRY),$(FILES_WIN32))
DIRS_BUILD_TMP      := $(call FIND_TMPDIRS,$(SRCDIR),$(LINUX))
DIRS_BUILD_TMP      += $(call FIND_TMPDIRS,$(SRCDIR),$(WIN32))
DIRS_BUILD_TMP      += $(call FIND_TMPDIRS,$(TESTDIR),$(LINUX))
DIRS_BUILD_TMP      += $(call FIND_TMPDIRS,$(TESTDIR),$(WIN32))

# ==============================================================================
# OBJECT AND DEPENDENCY FILE TARGETS DERIVED FROM SOURCE FILES
# ==============================================================================

# This is basically the heart of the build because it rewrites any sources found
# above to the object and header dependency files we expect to create from them.
# We can then set them as prerequisites for the final linker step and they will
# be compiled according to the pattern rules defined a few sections below. It's
# semantically questionable to include OBJECTS_X in OBJECTS_TESTS_X but ehh.

OBJECTS_LINUX        := $(call REPLACE_EXT,o,$(LINUX),FILES_LINUX)
OBJECTS_WIN32        := $(call REPLACE_EXT,o,$(WIN32),FILES_WIN32)
OBJECTS_TESTS_LINUX  := $(call REPLACE_EXT,o,$(LINUX),FILES_TESTS_LINUX)
OBJECTS_TESTS_LINUX  += $(call REPLACE_EXT,o,$(LINUX),FILES_LINUX_NOMAIN)
OBJECTS_TESTS_WIN32  := $(call REPLACE_EXT,o,$(WIN32),FILES_TESTS_WIN32)
OBJECTS_TESTS_WIN32  += $(call REPLACE_EXT,o,$(WIN32),FILES_WIN32_NOMAIN)
DEPENDS_LINUX        := $(call REPLACE_EXT,d,$(LINUX),FILES_LINUX)
DEPENDS_WIN32        := $(call REPLACE_EXT,d,$(WIN32),FILES_WIN32)
DEPENDS_TESTS_LINUX  := $(call REPLACE_EXT,d,$(LINUX),FILES_TESTS_LINUX)
DEPENDS_TESTS_WIN32  := $(call REPLACE_EXT,d,$(WIN32),FILES_TESTS_WIN32)

# ==============================================================================
# PRIMARY BUILD TARGETS
# ==============================================================================

.PHONY: all
all: release check

$(TARGET_LINUX): $(OBJECTS_LINUX) $(DEPENDS_LINUX) | $(SRCDIR) $(BINDIR)
	$(call LINK,LINUX,OBJECTS_LINUX)
$(TARGET_WIN32): $(OBJECTS_WIN32) $(DEPENDS_WIN32) | $(SRCDIR) $(BINDIR)
	$(call LINK,WIN32,OBJECTS_WIN32)
$(TARGET_LINUX_TEST): $(OBJECTS_TESTS_LINUX) $(DEPENDS_TESTS_LINUX) | $(TESTDIR) $(BINDIR)
	$(call LINK,LINUX,OBJECTS_TESTS_LINUX)
$(TARGET_WIN32_TEST): $(OBJECTS_TESTS_WIN32) $(DEPENDS_TESTS_WIN32) | $(TESTDIR) $(BINDIR)
	$(call LINK,WIN32,OBJECTS_TESTS_WIN32)

# ==============================================================================
# PATTERN RULES
# ==============================================================================

# We must expand the prerequisite lists a second time to resolve path variable
# $(@D). This means folders can be set as explicit dependencies and created in
# the $DIRS_BUILD_TMP rule. This is better than relying on Make to honor order
# of prerequisites for the primary target and we will not have to call mkdir
# for each build step preemptively.

.SECONDEXPANSION:

$(TMPDIR)/$(LINUX)/%.o: %.c | $$(@D)
	$(call COMPILE,CC,LINUX,CFLAGS)
$(TMPDIR)/$(LINUX)/%.o: %.cpp | $$(@D)
	$(call COMPILE,CXX,LINUX,CXXFLAGS)
$(TMPDIR)/$(LINUX)/%.d: %.c | $$(@D)
	$(call MAKEDEP,CC,LINUX)
$(TMPDIR)/$(LINUX)/%.d: %.cpp | $$(@D)
	$(call MAKEDEP,CXX,LINUX)
$(TMPDIR)/$(WIN32)/%.o: %.c | $$(@D)
	$(call COMPILE,CC,WIN32,CFLAGS)
$(TMPDIR)/$(WIN32)/%.o: %.cpp | $$(@D)
	$(call COMPILE,CXX,WIN32,CXXFLAGS)
$(TMPDIR)/$(WIN32)/%.d: %.c | $$(@D)
	$(call MAKEDEP,CC,WIN32)
$(TMPDIR)/$(WIN32)/%.d: %.cpp | $$(@D)
	$(call MAKEDEP,CXX,WIN32)

# ==============================================================================
# DIRECTORY TARGETS LIST
# ==============================================================================

$(SRCDIR)  \
$(BINDIR)  \
$(TESTDIR) \
$(DATADIR) \
$(DIRS_BUILD_TMP):
	$(E) "[DIR] $@"
	$(Q) $(MKDIR) $@

# ==============================================================================
# CHECK, RELEASE AND INSTALL TARGETS
# ==============================================================================

.PHONY: check
# Skip check stage if no unit test sources were found
ifneq ($(strip $(FILES_TESTS_LINUX) $(FILES_TESTS_WIN32)),)
check: $(TARGET_LINUX_TEST) $(TARGET_WIN32_TEST)
	$(Q) $(TARGET_LINUX_TEST)
	$(Q) $(TARGET_WIN32_TEST)
else
check:
	$(E) "[CHK] No unit-tests found."
endif

.PHONY: release
release: $(RELEASE_LINUX) $(RELEASE_WIN32)

$(RELEASE_LINUX): $(TARGET_LINUX) | $(DATADIR)
	$(E) "[TAR] $(RELEASE_LINUX)"
	$(Q) $(TAR) -cf $(RELEASE_LINUX) $(DATADIR) -C $(BINDIR)/$(LINUX) .

$(RELEASE_WIN32): $(TARGET_WIN32) | $(DATADIR)
	$(E) "[TAR] $(RELEASE_WIN32)"
	$(Q) $(TAR) -cf $(RELEASE_WIN32) $(DATADIR) -C $(BINDIR)/$(WIN32) .

.PHONY: install
install: $(TARGET_LINUX) $(TARGET_WIN32)
	$(E) "No install target yet."

# ==============================================================================
# AUXILIARY TARGETS
# ==============================================================================

.PHONY: clean
clean:
	$(E) "[REM] $(TARGET_LINUX)"
	$(Q) $(RM) $(TARGET_LINUX)
	$(E) "[REM] $(TARGET_LINUX_TEST)"
	$(Q) $(RM) $(TARGET_LINUX_TEST)
	$(E) "[REM] $(TARGET_WIN32)"
	$(Q) $(RM) $(TARGET_WIN32)
	$(E) "[REM] $(TARGET_WIN32_TEST)"
	$(Q) $(RM) $(TARGET_WIN32_TEST)
	$(E) "[REM] $(RELEASE_LINUX)"
	$(Q) $(RM) $(RELEASE_LINUX)
	$(E) "[REM] $(RELEASE_WIN32)"
	$(Q) $(RM) $(RELEASE_WIN32)
	$(E) "[REM] $(TMPDIR)"
	$(Q) $(RM) -r $(TMPDIR)

.PHONY: distclean
distclean: clean
	$(E) "[REM] $(BINDIR)"
	$(Q) $(RM) -r $(BINDIR)
	$(E) "[REM] .settings.mk"
	$(Q) $(RM) .settings.mk

# ==============================================================================
# MAKE PREPROCESSOR INCLUDES AND CONDITIONALS
# ==============================================================================

# Exported settings
include .settings.mk
# Generated header dependency files
include $(wildcard $(DEPENDS_LINUX))
include $(wildcard $(DEPENDS_WIN32))
include $(wildcard $(DEPENDS_TESTS_LINUX))
include $(wildcard $(DEPENDS_TESTS_WIN32))
# Use CC if there are no C++ sources
# Not really necessary but feels right...
CXXFILES += $(filter %.cpp,$(FILES_LINUX))
CXXFILES += $(filter %.cpp,$(FILES_WIN32))
CXXFILES += $(filter %.cpp,$(FILES_TESTS_LINUX))
CXXFILES += $(filter %.cpp,$(FILES_TESTS_WIN32))
ifeq ($(strip $(CXXFILES)),)
LD_LINUX := $(CC_LINUX)
LD_WIN32 := $(CC_WIN32)
endif
# Build verbosity setting
ifneq ($(VERBOSE), false)
E = @true
else
E = @echo
Q = @
endif
ifeq ($(OS),WIN32)
# Windows with WSL
endif
ifeq ($(OS),LINUX)
# Native Linux
endif
