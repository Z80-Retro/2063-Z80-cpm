# Create the CP/M source code file we need by downloading and extracting it

all: CPM22.Z80 filesystem

CPM22.Z80: cpm2-asm.zip
	unzip cpm2-asm.zip $@
	touch $@

cpm2-asm.zip:
	wget http://www.cpm.z80.de/download/cpm2-asm.zip

cpm22-b.zip:
	wget http://www.cpm.z80.de/download/cpm22-b.zip

filesystem: cpm22-b.zip
	mkdir -p filesystem
	unzip -d filesystem cpm22-b.zip

# Note that clean here will delete the CPM22 files but keep the zip file!
clean:
	rm -f CPM22.* READ.ME
	rm -rf filesystem
