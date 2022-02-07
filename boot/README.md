# A FLASH boot loader for Z80 Retro!

This is a discussion on how to partition an SD card on Linux using parted.  
(Note that partition type 0x7f is reserved for experimental use.)

The problem with CP/M disks is that they do not include any sort of
signature to indicate their geometry.  So it is unlikely that any
CP/M filesystem will be readable by any system unl;ess it has its
configuration hard-coded!

	sudo parted /dev/sda

To create a disk for hacking, it is likely best to create a partition 
for the CP/M drives of type 0x7f that is `16*8*1024*1024` bytes in size 
(128MiB.)  (The idea being that one partition could hold 16, 8MB disks.)

DANGER!!  THE FOLLOWING CAN CAUSE CATESTROPHIC DATA LOSS TO YOUR ENTIRE
SYSTEM!... NOT JUST THE SD CARD!

Before doing anything discussed here, make VERY sure that you know what the 
name of your SD card is on the system you are running the following commands.  
On a Raspberry PI, with a USB-SD card adapter, the SD card in the adapter 
(as opposed to the one running the PI) is *PROBABLY* called `/dev/sda`.

First, wipe out any existing MBR.  Doing so will effectively 're-format' your SD card.
Do *NOT* expect that you will be able to recover any data after doing this!

On my raspberry PI, with only one SD adapter plugged into a USB port, I use the 
following command:

	sudo dd if=/dev/zero of=/dev/sda bs=512 count=10

Once that is completed, the `parted` command can be used to create a partition.

	sudo parted /dev/sda
	(parted) mklabel msdos                                                    
	(parted) mkpart primary 1 135
	(parted) mkpart primary 1MiB 129MiB
	(parted) print
	Model: Generic MassStorageClass (scsi)
	Disk /dev/sda: 15.6GB
	Sector size (logical/physical): 512B/512B
	Partition Table: msdos
	Disk Flags: 
	
	Number  Start   End    Size   Type     File system  Flags
 	1      1049kB  135MB  134MB  primary               lba
	
	(parted) q                                                                

This partioning is not optiomal, but should suffice.  (At some point,
I will write a simple C prog to emit a minimal MBR with a type 0x7F
partion in it.)

After creating the MBR, you can look at it using `hexdumpo -C`

	sudo dd if=/dev/sda bs=512 count=1 2>/dev/null | hexdump -C       
	00000000  fa b8 00 10 8e d0 bc 00  b0 b8 00 00 8e d8 8e c0  |................|
	00000010  fb be 00 7c bf 00 06 b9  00 02 f3 a4 ea 21 06 00  |...|.........!..|
	00000020  00 be be 07 38 04 75 0b  83 c6 10 81 fe fe 07 75  |....8.u........u|
	00000030  f3 eb 16 b4 02 b0 01 bb  00 7c b2 80 8a 74 01 8b  |.........|...t..|
	00000040  4c 02 cd 13 ea 00 7c 00  00 eb fe 00 00 00 00 00  |L.....|.........|
	00000050  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	*
	000001b0  00 00 00 00 00 00 00 00  4c 3c 43 c3 00 00 00 04  |........L<C.....|
	000001c0  01 04 83 05 82 06 00 08  00 00 00 00 04 00 00 00  |................|
	000001d0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	*
	000001f0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 55 aa  |..............U.|
	00000200

The four partition entries start at offset 0x000001be:

	00 04 01 04 83 05 82 06 00 08 00 00 00 00 04 00		<------ my partition!!!
	00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

	00			= inactive (not bootable)
	04 01 04	= CHS of the first sector
	83			= partition type (0x83 = Linux = probably not a good idea)
	05 82 06	= CHS of the last sector
	00 08 00 00 = LBA of first sector (1,048,576 = 0x800 * 0x200)
	00 00 04 00 = number of sectors in the partition (0x040000 = 262144, 262144*512 = 134217728 = 128MiB)





############################################################################
20211031 jrw

On a PI-hosted dev system:

~/2065-Z80-programmer/pi/flash < firmware.bin