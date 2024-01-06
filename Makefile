.DELETE_ON_ERROR:
.SUFFIXES:

# Makefile
# Written by Leon Krieg <info@madcow.dev>

# Please run ./configure once before invoking make to ensure the environment is
# properly set up. The build system will by default compile any C and C++ source
# files found in SRCDIR for both Linux and Windows and then link the resulting
# object files with the appropriate linker. All temporary build files are placed
# in TMPDIR. The release target will generate tarballs containing the binaries,
# assets from DATADIR and the gcc runtime libraries required for windows.

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
# TMPDIR        Temporary object and header dependencies directory.
# LINUX         Linux subdirectory of SYSDIR, tarball suffix, etc.
# WIN32         Win32 subdirectory of SYSDIR, tarball suffix, etc.

PROJECT         := template
VERBOSE         := false
SRCDIR          := src
SYSDIR          := src/system
BINDIR          := bin
DATADIR         := data
TMPDIR          := build
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

CC_LINUX        ?= x86_64-linux-gnu-gcc
CC_WIN32        ?= x86_64-w64-mingw32-gcc
CXX_LINUX       ?= x86_64-linux-gnu-g++
CXX_WIN32       ?= x86_64-w64-mingw32-g++
LD_LINUX        := $(CXX_LINUX)
LD_WIN32        := $(CXX_WIN32)
TARGET_LINUX    := $(BINDIR)/$(LINUX)/$(PROJECT)
TARGET_WIN32    := $(BINDIR)/$(WIN32)/$(PROJECT).exe
RELEASE_LINUX   := $(BINDIR)/$(PROJECT)-$(LINUX)_64.tar
RELEASE_WIN32   := $(BINDIR)/$(PROJECT)-$(WIN32)_64.tar
CPPFLAGS_LINUX  := $(CPPFLAGS) -DLINUX -D_POSIX_C_SOURCE=$(POSIXDEF)
CPPFLAGS_WIN32  := $(CPPFLAGS) -DWIN32 -DWIN32_LEAN_AND_MEAN
CFLAGS_LINUX    := $(CFLAGS)
CFLAGS_WIN32    := $(CFLAGS)
CXXFLAGS_LINUX  := $(CXXFLAGS)
CXXFLAGS_WIN32  := $(CXXFLAGS)
LDFLAGS_LINUX   := $(LDFLAGS)
LDFLAGS_WIN32   := $(LDFLAGS) "-Wl,--subsystem,console"
LDLIBS_LINUX    := $(LDLIBS)
LDLIBS_WIN32    := $(LDLIBS) -lgdi32
MDFLAGS_LINUX    = $(MDFLAGS)
MDFLAGS_WIN32    = $(MDFLAGS)

# ==============================================================================
# SOURCE FILE LISTS
# ==============================================================================

# Automatically scanning for required sources instead of having to list them all
# by hand is my primary reason for preferring the GNU make implementation over
# the POSIX standard. But the way system directories are excluded could still be
# improved because the wildcard globbing will wastefully iterate through them.

CFILES          := $(shell find "$(SRCDIR)" -name "*.c" -not -path "$(SYSDIR)/*" 2>/dev/null)
CFILES_LINUX    := $(CFILES) $(shell find "$(SYSDIR)/$(LINUX)" -name "*.c" 2>/dev/null)
CFILES_WIN32    := $(CFILES) $(shell find "$(SYSDIR)/$(WIN32)" -name "*.c" 2>/dev/null)
CXXFILES        := $(shell find "$(SRCDIR)" -name "*.cpp" -not -path "$(SYSDIR)/*" 2>/dev/null)
CXXFILES_LINUX  := $(CXXFILES) $(shell find "$(SYSDIR)/$(LINUX)" -name "*.cpp" 2>/dev/null)
CXXFILES_WIN32  := $(CXXFILES) $(shell find "$(SYSDIR)/$(WIN32)" -name "*.cpp" 2>/dev/null)
TMPDIRS         := $(patsubst %,$(TMPDIR)/$(WIN32)/%, $(shell find $(SRCDIR) -type d 2>/dev/null))
TMPDIRS         += $(patsubst %,$(TMPDIR)/$(LINUX)/%, $(shell find $(SRCDIR) -type d 2>/dev/null))

# ==============================================================================
# OBJECT AND DEPENDENCY FILE TARGETS DERIVED FROM SOURCE FILES
# ==============================================================================

# This is basically the heart of the build because it rewrites any sources found
# above to the object and header dependency files we expect to create from them.
# We can then set them as prerequisites for the final linker step and they will
# be compiled according to the pattern rules defined a few sections below.

OBJFILES_LINUX  := $(CFILES_LINUX:%.c=$(TMPDIR)/$(LINUX)/%.o)
OBJFILES_LINUX  += $(CXXFILES_LINUX:%.cpp=$(TMPDIR)/$(LINUX)/%.o)
OBJFILES_WIN32  := $(CFILES_WIN32:%.c=$(TMPDIR)/$(WIN32)/%.o)
OBJFILES_WIN32  += $(CXXFILES_WIN32:%.cpp=$(TMPDIR)/$(WIN32)/%.o)
DEPFILES_LINUX  := $(CFILES_LINUX:%.c=$(TMPDIR)/$(LINUX)/%.d)
DEPFILES_LINUX  += $(CXXFILES_LINUX:%.cpp=$(TMPDIR)/$(LINUX)/%.d)
DEPFILES_WIN32  := $(CFILES_WIN32:%.c=$(TMPDIR)/$(WIN32)/%.d)
DEPFILES_WIN32  += $(CXXFILES_WIN32:%.cpp=$(TMPDIR)/$(WIN32)/%.d)

# ==============================================================================
# HELPER MACROS (EVALUATE TO FINAL COMPILER AND LINKER COMMANDS)
# ==============================================================================

# These helper macros are here to reduce the amount of boilerplace code for the
# following rules below. They are simple variable substitutions to select the
# tools and flags for the target operating system.

define LINK
$(E) "[BIN] $@"; $(MKDIR) $(@D)
$(Q) $(LD_$(1)) -o $@ $(LDFLAGS_$(1)) $(OBJFILES_$(1)) $(LDLIBS_$(1))
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
# PRIMARY BUILD TARGETS
# ==============================================================================

.PHONY: all
all: release

$(TARGET_WIN32): $(OBJFILES_WIN32) $(DEPFILES_WIN32) | $(SRCDIR) $(BINDIR)
	$(call LINK,WIN32)

$(TARGET_LINUX): $(OBJFILES_LINUX) $(DEPFILES_LINUX) | $(SRCDIR) $(BINDIR)
	$(call LINK,LINUX)

# ==============================================================================
# PATTERN RULES
# ==============================================================================

# We must expand the prerequisite lists a second time to resolve path variable
# $(@D). This means folders can be set as explicit dependencies and created in
# the $TMPDIRS rule. This is better than relying on Make to honor the order of
# prerequisites for the primary target and we will not have to call mkdir for
# each build step preemptively.

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
$(DATADIR) \
$(TMPDIRS):
	$(E) "[DIR] $@"
	$(Q) $(MKDIR) $@

# ==============================================================================
# RELEASE AND INSTALL TARGETS
# ==============================================================================

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
	$(E) "[REM] $(TARGET_WIN32)"
	$(Q) $(RM) $(TARGET_WIN32)
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
include $(wildcard $(DEPFILES_LINUX))
include $(wildcard $(DEPFILES_WIN32))
# Use CC if there are no C++ sources
ifeq ($(strip $(CXXFILES_LINUX)),)
LD_LINUX := $(CC_LINUX)
endif
ifeq ($(strip $(CXXFILES_WIN32)),)
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
