# Create the CP/M source code file we need by downloading and extracting it

all: CPM22.Z80

CPM22.Z80: cpm2-asm.zip
	unzip cpm2-asm.zip CPM22.Z80

cpm2-asm.zip:
	wget www.cpm.z80.de/download/cpm2-asm.zip


# Note that clean here will delete the CPM22 files but keep the zip file!
clean:
	rm -f CPM22.* READ.ME
