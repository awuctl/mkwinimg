#!/usr/bin/env zsh

ISO=$1
DEVICE=$2

# For anyone reading this, don't get confused with variables
# {} blocks assign variables in the global scope, subshells don't

# stuff is put together in
# () || {}
# blocks to make it more readable
# (not to be confused with "readable", there are no readable shell scripts);
# the last expression in () decides its return value,
# if it indicates failure the {} block does cleanup and exits the script.

# for use in 7z params (only)
BOOT_FILES="sources/boot.wim boot/ efi/ autorun.inf bootmgr bootmgr.efi setup.exe"
INST_FILES="sources/ support/ -xr-!sources/boot.wim"

function printerr  { print -P "[%F{red}%BError%b%f] $1" }
function printwarn { print -P "[%F{yellow}%BWarning%b%f] $1" }
function printinfo { print -P "[%F{white}%BInfo%b%f] $1" }

if [[ $# -ne 2 ]]
then
    printerr 'Invalid parameter count!'
    print 'Usage: mkwinimg ISO DEVICE'
    exit 1
fi

#
# {{{ Stupidity checks
{
    [[ ! -f $1 ]] && \
        printerr "Invalid parameter, '$1' is not a file." && exit 1
    [[ ! -e $2 ]] && \
        printerr "Invalid parameter, '$2' does not exist." && exit 1
    [[ `whoami` != 'root' ]] && \
        printwarn 'You are not root. Continue? (y/N)' && {
            read -sq || { print 'Fine. Exiting..' ; exit }
        }
}
# Stupidity checks }}}


#
# {{{ Carelessness checks
{
    printwarn "You are about to completely obliterate '$DEVICE', are you sure? (y/N)" && {
        read -sq || { print 'Fine. Exiting.. ' ; exit } }
    { # print fdisk just to make sure.
        printinfo 'Just in case, fdisk output for that:'
        print ; fdisk -l "$DEVICE" ; print

        printinfo 'Are you still sure? (y/N)' && {
            read -sq || { print 'That was close. Exiting.' ; exit } }
    }
}
# Carelessness checks }}}

#
# {{{ Partitioning
{
    # Check file sizes..
    BOOT_FILE_SIZE=`7z l $ISO ${=BOOT_FILES} | tail -1 | awk '{print $3}'`
    INST_FILE_SIZE=`7z l $ISO ${=INST_FILES} | tail -1 | awk '{print $3}'`

    # Add an extra 128 MiB to each
    # and convert to KiB (for sgdisk)
    BOOT_FILE_SIZE=$[ ($BOOT_FILE_SIZE + (128 * (1024**2))) / 1024 ]
    INST_FILE_SIZE=$[ ($INST_FILE_SIZE + (128 * (1024**2))) / 1024 ]
    printinfo "Boot files are:    ${BOOT_FILE_SIZE} KiB"
    printinfo "Install files are: ${INST_FILE_SIZE} KiB"

    printinfo "Partitioning $DEVICE.."
    ( # create 1G part for boot, rest for install files
        sgdisk -Z "$DEVICE" &&
        sgdisk -n "1:2048:+${BOOT_FILE_SIZE}K" -t '1:ef00' "$DEVICE" &&

        sgdisk -n "2:0:+${INST_FILE_SIZE}K" -t '2:0700' "$DEVICE" # Microsoft Basic Data
    ) || {
        printerr 'Partitioning failed..'
        exit 1
    }
    # the partition tables could have not updated if the device was already mounted
    # TODO check for that.. or just preemptively umount the device
}
# Partitioning }}}

#
# {{{ Pit stop for defining stuff
{
    # wildcarding needed for "numbered" stuff (eg. "nvme0n0p1", "loop0p1")
    PART1=`realpath ${DEVICE}(p|)1`
    PART2=`realpath ${DEVICE}(p|)2`
    unset DEVICE # not used from here on

    # mountpoints
    MNT_BOOT=`mktemp -d --suffix=-BOOT`
    MNT_FILE=`mktemp -d --suffix=-INSTALL`
}
# Pit stop for defining stuff }}}

#
# {{{ Formatting and mounting
{
    ( printinfo "Creating filesystems.."
        mkfs.vfat -F32 $PART1 &&
        mkfs.ntfs -f   $PART2
    ) || {
        printerr 'Creating filesystems failed..'
        rmdir $MNT_BOOT $MNT_FILE
        exit 1
    }

    ( printinfo "Mounting in temporary directories (B:$MNT_BOOT, F:$MNT_FILE)"
        mount $PART1 "$MNT_BOOT" &&
        mount $PART2 "$MNT_FILE"
    ) || {
        printerr 'Mounting either filesystem failed. %BCleanup not performed%b for diagnostic purposes'
        exit 1
    }
}
# Formatting and mounting }}}

#
# {{{ Extraction
{
    ( printinfo 'Extracting files from the ISO'
        7z x $ISO ${=BOOT_FILES} -o$MNT_BOOT &&
        7z x $ISO 'sources/' 'support/' -x'r-!sources/boot.wim' -o$MNT_FILE
    ) || {
        printerr 'Extracting files failed. %BNot unmounting anything%b for diagnostic purposes.'
        exit 1
    }
}
# Extraction }}}

# Cleanup and exit

umount $PART1
umount $PART2
rmdir $MNT_BOOT $MNT_FILE
sync # just in case

printinfo '%F{green}Done! Good luck.%f'
exit