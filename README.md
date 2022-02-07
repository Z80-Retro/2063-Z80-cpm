# 2063-Z80-cpm
An SD card boot-loader and CP/M 2.2 BIOS for [Z80 Retro!](https://github.com/johnwinans/2063-Z80)

## Resources

![Simplified SD card specification](https://www.sdcard.org/downloads/pls/)
![Wikipedia SPI article](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface)
![Wikipedia MBR article](https://en.wikipedia.org/wiki/Master_boot_record)


# SD card partitioning

This is a discussion on how to partition an SD card on Linux using parted.  
(Note that partition type 0x7f is reserved for experimental use.)

The problem with CP/M disks is that they do not include any sort of
signature to indicate their geometry.  So it is unlikely that any
CP/M filesystem will be readable by any system unl;ess it has its
configuration hard-coded!

To create a disk for hacking, it is likely best to create a partition 
for the CP/M drives of type `0x7f` that is `16*8*1024*1024` bytes in size 
(128MiB.)  (The idea being that one partition could hold 16, 8MiB disks.)

## Danger Will Robinson!

DANGER!!  THE FOLLOWING CAN CAUSE CATASTROPHIC DATA LOSS TO YOUR ENTIRE
SYSTEM!... NOT JUST THE SD CARD!

Before doing anything discussed here, make VERY sure that you know what the 
name of your SD card is on the system you are running the following commands. 

On a Raspberry PI, with a USB-SD card adapter, the SD card in the adapter 
(as opposed to the one running the PI) is *PROBABLY* called `/dev/sda`.

## Erase(ish) your SD card

First, wipe out any existing MBR.  Doing so will effectively 're-format' your SD card.
Do *NOT* expect that you will be able to recover any data after doing this!

On my raspberry PI, with only one SD adapter plugged into a USB port, I use the 
following command:

	sudo dd if=/dev/zero of=/dev/sda bs=512 count=10

## Partition your SD card

Once that is completed, the `parted` command can be used to create a partition.

	sudo parted /dev/sda
	(parted) mklabel msdos                                                    
	(parted) mkpart primary 1 135
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

## Inspect the MBR

After creating the MBR, you can look at it using `hexdump -C`

	sudo dd if=/dev/sda bs=512 count=1 2>/dev/null | hexdump -C       

	00000000  fa b8 00 10 8e d0 bc 00  b0 b8 00 00 8e d8 8e c0  |................|
	00000010  fb be 00 7c bf 00 06 b9  00 02 f3 a4 ea 21 06 00  |...|.........!..|
	00000020  00 be be 07 38 04 75 0b  83 c6 10 81 fe fe 07 75  |....8.u........u|
	00000030  f3 eb 16 b4 02 b0 01 bb  00 7c b2 80 8a 74 01 8b  |.........|...t..|
	00000040  4c 02 cd 13 ea 00 7c 00  00 eb fe 00 00 00 00 00  |L.....|.........|
	00000050  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	*
	000001b0  00 00 00 00 00 00 00 00  68 1f 08 1f 00 00 00 20  |........h...... |
	000001c0  21 00 83 71 21 10 00 08  00 00 00 00 04 00 00 00  |!..q!...........|
	000001d0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	*
	000001f0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 55 aa  |..............U.|
	00000200

The four partition entries start at offset 0x000001be:

	00 20 21 00 83 71 21 10 00 08 00 00 00 00 04 00    <------ my partition!!!
	00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

	00          = inactive (not bootable)
	20 21 00    = CHS of the first sector (don't care)
	83          = partition type (0x83 = Linux = probably not a good idea)
	71 21 10    = CHS of the last sector (don't care)
	00 08 00 00 = LBA of first sector (1,048,576 = 0x800 * 0x200)
	00 00 04 00 = number of sectors in the partition (0x040000 = 262144, 262144*512 = 134217728 = 128MiB)

At this point, Liunux should recognize that the drive has one partition on it:

	ls -al /dev/sda*
	brw-rw---- 1 root disk 8, 0 Feb  7 14:59 /dev/sda
	brw-rw---- 1 root disk 8, 1 Feb  7 14:59 /dev/sda1

`/dev/sda` is a view of the entire raw drive.

`/dev/sda1` is a view of only partion 1.

## Write test data into the partition

If we write "Hello world!" into partition 1:

	echo "Hello world!" | sudo dd of=/dev/sda1 bs=512

...then we can see it by looking at the raw disk image:

	sudo dd if=/dev/sda bs=512 count=9000 2>/dev/null | hexdump -C
	
	00000000  fa b8 00 10 8e d0 bc 00  b0 b8 00 00 8e d8 8e c0  |................|
	00000010  fb be 00 7c bf 00 06 b9  00 02 f3 a4 ea 21 06 00  |...|.........!..|
	00000020  00 be be 07 38 04 75 0b  83 c6 10 81 fe fe 07 75  |....8.u........u|
	00000030  f3 eb 16 b4 02 b0 01 bb  00 7c b2 80 8a 74 01 8b  |.........|...t..|
	00000040  4c 02 cd 13 ea 00 7c 00  00 eb fe 00 00 00 00 00  |L.....|.........|
	00000050  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	*
	000001b0  00 00 00 00 00 00 00 00  68 1f 08 1f 00 00 00 20  |........h...... |
	000001c0  21 00 83 71 21 10 00 08  00 00 00 00 04 00 00 00  |!..q!...........|
	000001d0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	*
	000001f0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 55 aa  |..............U.|
	00000200  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	*
	00100000  48 65 6c 6c 6f 20 77 6f  72 6c 64 21 0a 00 00 00  |Hello world!....|
	00100010  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	*
	00465000

...and we can also see it by looking at the raw partion image:

	sudo dd if=/dev/sda1 bs=512 count=9000 2>/dev/null | hexdump -C

	00000000  48 65 6c 6c 6f 20 77 6f  72 6c 64 21 0a 00 00 00  |Hello world!....|
	00000010  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	*
	00465000

Note that from the perspective of the whole drive, the string starts at `0x00100000`
and from the perspective of the partition, it starts at `0x00000000`.

Recall that partition 1 starts at LBA  block number `0x800`, which is at byte offset 
`0x800*0x200 = 0x00100000` from the start of the raw disk image.

Therefore, we can use `dd` to copy raw binary images into either the entire drive starting
at block number 0 (where the MBR is) or into any partition from their respective begining.

## Boot a Hello World! app from the SD card

See the code in ![./hello](/hello) to create a program that will load and run from the SD card.
