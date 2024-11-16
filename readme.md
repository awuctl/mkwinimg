# mkwinimg

This creates a **bootable** Windows Installer device for booting on UEFI systems.

You can use this to make a bootable Windows USB drive.

This is not something I use very often, so don't expect much development.

## Requirements

You need the following stuff:

 * zsh
 * 7-Zip / p7zip (for `7z`)
 * gdisk / gptfdisk (for `fdisk`)
 * dosfstools (for `mkfs.vfat`)
 * ntfs-3g (for `mkfs.ntfs`)
 * gawk (for `awk`)

Most distros will have the majority by default.

On Arch Linux you can install all these with:

```sh
pacman -Sy --needed zsh p7zip ntfs-3g parted dosfstools gptfdisk gawk
```

## Usage

```
Usage: mkwinimg.sh ISO DEVICE
```

`ISO` is the path to the ISO you wish to use.

`DEVICE` is the path to the device you wish to use. You can use `loop` devices with this.

### Examples

#### Bootable Device

Make a bootable USB drive (`/dev/sdb`) using an ISO:
```sh
mkwinimg.sh 'Win10_21H2_English_x64.iso' /dev/sdb
```

#### Raw Image

Create an image file for `dd`-ing  later.
```sh
truncate --size 8G win10.img
losetup --show -P -f win10.img
# ↑ gives you the name (eg. /dev/loop1)
mkwinimg.sh 'CMGE_V2020-L.1207.iso' /dev/loop1
losetup -d /dev/loop1
```
To make it as small as possible: 
```sh
fdisk -l win10.img # multiply sector size by last end sector
truncate --size (result_goes_here) win10.img
```

To apply it to a device (`/dev/sdb` here):

```sh
dd if=win10.img of=/dev/sdb bs=1M status=progress oflag=sync
```

## Disclaimer

This will **not** work with BIOS/Legacy systems.

You can't make anything of the sort work cleanly with BIOS because the "people" responsible for the Windows Installer are either idiots or (if they broke it on purpose) cunts. I won't elaborate on that.
