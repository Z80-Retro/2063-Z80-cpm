

Use 'make' to assemble the BIOS:
```
make
```

Partition your SD card precisely as described in [../README-SD.md](../README-SD.md) 
so that partition 1 starts exactly at block number 0x800 (1MiB) or the first draft 
of the BIOS will not work properly!

**IFF you are developing on a Raspberry PI**, You can install your assembled BIOS 
onto SD card partition 1 like this:

```
sudo dd if=retro.bin of=/dev/sda1 bs=512
```

On other systems, the drive name may be different!  
**Using the wrong drive name can destroy all your data!**
