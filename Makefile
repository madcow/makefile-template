.DELETE_ON_ERROR:
.SUFFIXES:

# Build Configuration
# Written by Leon Krieg <info@madcow.dev>

# Run ./configure once after cloning the repository to ensure your environment
# is properly set up. The build system will compile C and C++ sources from the
# SRCDIR and link the resulting object files as both linux and win32 binaries.
# Plain C sources are compiled with gcc and the appropriate linker is selected
# based on if there are any C++ source files in SRCDIR. Build related files are
# placed in TMPDIR and dependencies from included headers are generated using
# the preprocessor. Run 'make release' to create tarballs for all systems.

ifeq ($(wildcard .settings.mk),)
$(error Please run ./configure first.)
endif

include .settings.mk
ifeq ($(OS),WIN32)
# Windows with WSL
endif
ifeq ($(OS),LINUX)
# Native Linux
endif

# ==============================================================================
# PROJECT SETTINGS
# ==============================================================================

# PROJECT       Project identifier.
# VERBOSE       Show full text for every command?
# SRCDIR        Location of C and C++ source files.
# SYSDIR        Location of platform-dependend source files.
# LINUX         Subdirectory of SYSDIR, tarball suffix, etc.
# WIN32         Subdirectory of SYSDIR, tarball suffix, etc.
# BINDIR        Binaries and dynamic libraries.
# DATADIR       Data files to be copied into tarball.
# TMPDIR        Objects and header dependency files.

PROJECT         := template
VERBOSE         := false
SRCDIR          := src
SYSDIR          := src/system
LINUX           := linux
WIN32           := win32
BINDIR          := bin
DATADIR         := data
TMPDIR          := build

# ==============================================================================
# TOOLCHAIN GENERAL SETTINGS
# ==============================================================================

# WFLAGS        Compiler error flags.
# CPPFLAGS      Shared preprocessor flags.
# CFLAGS        Compiler flags for C excluding error settings.
# CXXFLAGS      Compiler flags for C++ excluding error settings.
# MDFLAGS       Automatic preprocessor header dependency flags.
# LDFLAGS       Linker settings, passed to compiler - not ld.
# LDLIBS        Required linker library imports.
# POSIXDEF      POSIX version to use on linux.

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
LDFLAGS_WIN32   := $(LDFLAGS)
LDLIBS_LINUX    := $(LDLIBS)
LDLIBS_WIN32    := $(LDLIBS)
MDFLAGS_LINUX    = $(MDFLAGS)
MDFLAGS_WIN32    = $(MDFLAGS)

# ==============================================================================
# SOURCE FILE LISTS
# ==============================================================================

CFILES          := $(shell find "$(SRCDIR)" -name "*.c" -not -path "$(SYSDIR)/*" 2>/dev/null)
CFILES_LINUX    := $(CFILES) $(shell find "$(SYSDIR)/$(LINUX)" -name "*.c" 2>/dev/null)
CFILES_WIN32    := $(CFILES) $(shell find "$(SYSDIR)/$(WIN32)" -name "*.c" 2>/dev/null)
CXXFILES        := $(shell find "$(SRCDIR)" -name "*.cpp" -not -path "$(SYSDIR)/*" 2>/dev/null)
CXXFILES_LINUX  := $(CXXFILES) $(shell find "$(SYSDIR)/$(LINUX)" -name "*.cpp" 2>/dev/null)
CXXFILES_WIN32  := $(CXXFILES) $(shell find "$(SYSDIR)/$(WIN32)" -name "*.cpp" 2>/dev/null)
TMPDIRS         := $(patsubst %,$(TMPDIR)/$(WIN32)/%, $(shell find $(SRCDIR) -type d 2>/dev/null))
TMPDIRS         += $(patsubst %,$(TMPDIR)/$(LINUX)/%, $(shell find $(SRCDIR) -type d 2>/dev/null))

# Use CC if there are no C++ sources
ifeq ($(strip $(CXXFILES_LINUX)),)
LD_LINUX := $(CC_LINUX)
endif
ifeq ($(strip $(CXXFILES_WIN32)),)
LD_WIN32 := $(CC_WIN32)
endif

# ==============================================================================
# OBJECT AND DEPENDENCY FILE TARGETS DERIVED FROM SOURCE FILES
# ==============================================================================

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

# Must expand the prerequisite lists a second time to resolve the path variable
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

# ======================================================================
# DIRECTORY TARGETS LIST
# ======================================================================

$(SRCDIR)  \
$(BINDIR)  \
$(DATADIR) \
$(TMPDIRS):
	$(E) "[DIR] $@"
	$(Q) $(MKDIR) $@

# ======================================================================
# RELEASE AND INSTALL TARGETS
# ======================================================================

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

# ======================================================================
# AUXILIARY TARGETS
# ======================================================================

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

# ======================================================================
# PREPROCESSOR INCLUDES AND CONDITIONALS
# ======================================================================

include $(wildcard $(DEPFILES_LINUX))
include $(wildcard $(DEPFILES_WIN32))
ifneq ($(VERBOSE), false)
E = @true
else
E = @echo
Q = @
endif
