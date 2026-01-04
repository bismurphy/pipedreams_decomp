ASM_DIR         := asm
BIN_DIR         := bin
SRC_DIR         := src
BUILD_DIR       := build
TOOLS_DIR       := tools
CONFIG_DIR      := config


TARGETS         := SLUS_014.09
SPLAT           := splat split

CROSS           := mipsel-linux-gnu-
OBJCOPY         := $(CROSS)objcopy

CPP             := $(CROSS)cpp
CPP_FLAGS       += -Iinclude -undef -Wall -fno-builtin
CPP_FLAGS       += -Dmips -D__GNUC__=2 -D__OPTIMIZE__ -D__mips__ -D__mips -Dpsx -D__psx__ -D__psx -D_PSYQ -D__EXTENSIONS__ -D_MIPSEL -D_LANGUAGE_C -DLANGUAGE_C -DNO_LOGS -DHACKS -DUSE_INCLUDE_ASM

# This is your compiler - be very prepared to change it.
# Get your compiler from: https://github.com/decompals/old-gcc/releases
# select any gcc-#.#.#-psx.tar.gz file.
CC1PSX          := ./bin/cc1-psx-272
CC              := $(CC1PSX)
CC_FLAGS        += -G0 -w -O2 -gcoff -quiet

PYTHON          := python3
MASPSX_DIR      := $(TOOLS_DIR)/maspsx
MASPSX_APP      := $(MASPSX_DIR)/maspsx.py
MASPSX_FLAGS    := --expand-div --aspsx-version=2.05 -G4 --use-comm-section
MASPSX          := $(PYTHON) $(MASPSX_APP) $(MASPSX_FLAGS)

AS              := $(CROSS)as
AS_FLAGS        += -Iinclude -march=r3000 -no-pad-sections -G0

LD              := $(CROSS)ld
LD_FLAGS        := -nostdlib --no-check-sections

define list_src_files
	$(info List src file argument: $(1))
	$(foreach dir,$(ASM_DIR)/$(1),$(wildcard $(dir)/**.s))
	$(foreach dir,$(ASM_DIR)/$(1)/data,$(wildcard $(dir)/**.s))
	$(foreach dir,$(SRC_DIR)/$(1),$(wildcard $(dir)/**.c))
endef

define list_o_files
	$(info O file argument: $(1))
	$(eval FILES := $(foreach file,$(call list_src_files,$(1)),$(BUILD_DIR)/$(file).o))
	$(info O files found: $(FILES))
	$(FILES)
endef

define link
	$(info Linking: $(1) /// $(2) /// $(LD) /// $(LD_FLAGS))
	$(LD) $(LD_FLAGS) -o $(2) \
		-Map $(BUILD_DIR)/$(1).map \
		-T $(BUILD_DIR)/$(1).ld \
		-T $(CONFIG_DIR)/undefined_syms.txt \
		-T $(CONFIG_DIR)/undefined_syms_auto.txt\
		-T $(CONFIG_DIR)/undefined_syms_auto.$(1).txt
endef

$(BUILD_DIR)/%.c.o: %.c $(MASPSX_APP) $(CC1PSX)
	mkdir -p $(dir $@)
	$(CPP) $(CPP_FLAGS) -lang-c $< | $(CC) $(CC_FLAGS) | $(MASPSX) | $(AS) $(AS_FLAGS) -o $@

$(BUILD_DIR)/%.s.o: %.s
	mkdir -p $(dir $@)
	$(AS) $(AS_FLAGS) -o $@ $<

$(addprefix $(BUILD_DIR)/, $(TARGETS)): $(BUILD_DIR)/%: $(BUILD_DIR)/%.elf
	$(OBJCOPY) -O binary $< $@

.SECONDEXPANSION: # need second expansion to allow wildcard prereq in "call"
$(BUILD_DIR)/%.elf: $$(call list_o_files,%)
	$(call link,$*,$@)

MPISO_EXEC := tools/mkpsxiso/build/Release/dumpsxiso

tools/mkpsxiso: 
	mkdir -p tools && cd tools && git clone git@github.com:Lameguy64/mkpsxiso.git

$(MPISO_EXEC): tools/mkpsxiso
	cd tools/mkpsxiso && git submodule update --init --recursive && cmake -S . --preset release && cmake --build ./build --config Release

extract_disk: $(MPISO_EXEC)
	mkdir -p EXTRACTED
	cd GAME && ../$(MPISO_EXEC) pipedreams.cue -x ../EXTRACTED

extract: $(addprefix $(BUILD_DIR)/,$(addsuffix .ld,$(TARGETS)))
	$(info Extraction Complete.)

$(BUILD_DIR)/%.ld: $(CONFIG_DIR)/splat.%.yaml
	$(SPLAT) $<

all: build check

build: $(addprefix $(BUILD_DIR)/, $(TARGETS))

check: config/checksums.sha
	sha1sum --check $<

clean:
	rm -rf asm
	rm -rf build