# Mostly Copilot generated, hence all the comments

# Get the full path to the latest macOS SDK
MACOS_SDK_PATH := $(shell xcrun --sdk macosx --show-sdk-path)
# Extract the version number (e.g., 15.4) from the SDK path for the linker flag
MACOS_SDK_VERSION := $(shell xcrun --sdk macosx --show-sdk-version)

# Define the linker flags using the dynamically found paths/versions
# Note: The -e _start flag is used for the entry point in typical assembly
# The platform_version may need adjustment depending on the target macOS version,
# but using a high version (like 11.0) is often safe for modern systems.
LDFLAGS := -platform_version macos 11.0 $(MACOS_SDK_VERSION) -lSystem -L$(MACOS_SDK_PATH)/usr/lib -e _start

# Define the compiler command (nasm)
NASM_CMD = nasm -g -F dwarf -f macho64

# Define the linker command (ld)
LD_CMD = ld

# The .PHONY declaration ensures that make won't confuse a file named 05 with the target 05
.PHONY: $(DIRS)

# The main compilation pattern rule
# Target: The executable file (e.g., 05/main)
# Prerequisite: The object file (e.g., 05/main.o) which has an implicit rule defined below
%: %/main.o aocutils/utils.o
	$(LD_CMD) $^ -o $@/main $(LDFLAGS)

# Implicit rule for creating the object file
# Target: The object file (e.g., 05/main.o)
# Prerequisite: The source assembly file (e.g., 05/main.asm)
%/main.o: %/main.asm
	$(NASM_CMD) $< -o $@

# Rule for creating the utils object file
aocutils/utils.o: aocutils/utils.asm
	$(NASM_CMD) $< -o $@