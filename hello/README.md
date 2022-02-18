# A program that can be booted from the SD card

On a PI-hosted dev system:

Use this to save this program into partition 1:

    sudo dd if=hello.bin of=/dev/sda1 bs=512

Use this command to save this program into the raw disk drive (overwriting the MBR!)
	
    sudo dd if=/dev/zero of=/dev/sda bs=512 count=1
    sudo dd if=hello.bin of=/dev/sda bs=512
