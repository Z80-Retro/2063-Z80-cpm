Build a CP/M filesystem image for a Retro! bootable SD card.

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

For more apps that can run on your Retro! board, search the Internet for variations of `cp/m software downloads` and 'cp/m game download' etc.

Some big archives that might keep you busy for a while can be found here:

	http://cpmarchives.classiccmp.org/
	https://ifarchive.org/indexes/if-archiveXgamesXcpm.html

If you want something to cook on your CPU and test every instruction, you can try
`zexall.com` and `zexdoc.com` files found in the CPM.zip file located here:

	https://mdfs.net/Software/Z80/Exerciser/
