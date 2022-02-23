# A program that can be booted from the SD card

On a PI-hosted dev system:

Use this to save this program into partition 1 suitable for loading and executing by using the `firmware.asm` boot-ROM code in [../boot](../boot):


    sudo dd if=hello.bin of=/dev/sda1 bs=512

Use this command to save this program into the raw disk drive (overwriting the MBR!) suitable for loading and executing by using the `sd_test.asm` boot-ROM code in [../tests](../tests):

    sudo dd if=/dev/zero of=/dev/sda bs=512 count=1
    sudo dd if=hello.bin of=/dev/sda bs=512
