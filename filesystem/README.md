# Build a CP/M filesystem image for a Retro! bootable SD card.

## cpmtools

We can use the `cpmtools` package to do this.  On a Debian-derived linux system we can install it like this:

	sudo apt install cpmtools

It is not documented, but a `diskdefs` file in the current directory will be searched my the `cpmtools` commands for the given `-f` format:

	mkfs.cpm -f z80-retro-2k-8m retro.img

Note that the above will 0xe5 out the reserved tracks and nothing more.

To include the retro.bin CP/M os image on the reserved tracks, add it to the command like this:

	mkfs.cpm -f z80-retro-2k-8m -b ../retro/retro.bin retro.img

Once a filesystem has been initialized by the mkfs.cpm command, files can be added to it like this:

	cpmcp -f z80-retro-2k-8m retro.img ../cpm22/filesystem/* 0:

We can also look at what files are on the CP/M filesystem with the `cpmls` command like this:

	cpmls -f z80-retro-2k-8m retro.img

## Multiple filesystems on one SD card

Here is how to create and mount multiple filesystems on one SD card.

We consider the one SD partition as a series of 8 megabyte `slots`.  The goal is to write one disk image (filesystem) to each slot on the disk partition using the `dd` command by specifying where on the SD card to put each one.

We consider the slots to be numbered 0-15. 

Each slot is 16384 blocks in size (0x4000). seek=01x16384 - 16384 in decimal is the start of the
second disk slot. (You don't need the seek statement for disk 0, but it's included for consistency.)

Currently only disk slots 0-3 are supported by the Z80 Retro. It can support up to 16 8MB disks.
But, depending on the filesystem format, this can require 8K of RAM (512 byte ALV buffer per drive.)
We'll be looking more at this issue in the future.

	sudo dd if=0.img of=/dev/YourPartitionHere bs=512 seek=00x16384 conv=fsync  # slot 0
	sudo dd if=1.img of=/dev/YourPartitionHere bs=512 seek=01x16384 conv=fsync  # slot 1
	sudo dd if=2.img of=/dev/YourPartitionHere bs=512 seek=02x16384 conv=fsync  # slot 2
	sudo dd if=3.img of=/dev/YourPartitionHere bs=512 seek=03x16384 conv=fsync  # slot 3

Note that you must replace the `YourPartitionHere` with the disk partition representing your SD card.  It is different depending on your system configuration.  On a generic Raspberry PI, it is typically `/dev/sda1`.

Also note the different `seek` values and filesystem names on each of the above `dd` commands.

You don't have to write to each slot in any order. For instance if you wanted a new disk image in
slot 3, you could just write the new image to slot 3. It won't effect the other slots. The image in
slot 0 must contain the BIOS (retro.bin) or it won't boot. 

See the above examples of using `cpmtools` for clues on how to put files of your choice onto the disk images.



## Where to find CP/M programs for your system

For more apps that can run on your Retro! board, search the Internet for variations of `cp/m software downloads` and 'cp/m game download' etc.

Some big archives that might keep you busy for a while can be found here:

	http://cpmarchives.classiccmp.org/
	https://ifarchive.org/indexes/if-archiveXgamesXcpm.html
	https://deramp.com/downloads/mfe_archive/040-Software/Digital%20Research/CPM%20Implementations/COMPUPRO/GAMES/

If you want something to cook on your CPU and test every instruction, you can try
`zexall.com` and `zexdoc.com` files found in the CPM.zip file located here:

	https://mdfs.net/Software/Z80/Exerciser/
