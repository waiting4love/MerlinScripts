#!/bin/sh

# post-mount script designed to offload jffs to usb.
# 1. Create folder with name "jffs" under mount usb disk.
# 2. Create this script as /jffs/scripts/post-mount, chmod a+x it so it can be executed.
# 3. Be sure to check that 'Enable JFFS custom scripts and configs' is enabled under Administration->System.
# 4. Create symbolic link /jffs/scripts/unmount to /jffs/scripts/post-mount.
# 5. Reboot router.

IFS=$'\n'

JFFS_DISK=$(mount | grep -i /jffs | awk '{print $1}')
# Abort if we don't have a jffs mount point to begin with.
if [ -z "$JFFS_DISK" ]; then
    logger -s "No JFFS mount point detected, aborting USB->JFFS."
    exit 1
fi

MNT=$1

CUR_DISK=$(mount | grep -i $MNT | awk '{print $1}')

if [ "$JFFS_DISK" == "$CUR_DISK" ]; then
    ORIG_JFFS=$(cat $MNT/.jffs_sync/orig_jffs.map 2>/dev/null)
    if [ -z "$ORIG_JFFS" ]; then
        logger -s "Couldn't locate original jffs mount point: $1/.jffs_sync/orig_jffs.map."
        exit 1
    fi
    umount /jffs
    mount -t jffs2 -o rw,noatime $ORIG_JFFS /jffs
fi

# Return if we don't find a jffs folder.
if [ -z "$(find $MNT -name jffs 2>/dev/null)" ]; then
    logger -s "Couldn't locate jffs folder, skipping $1 as JFFS->USB."
    exit 1
fi

if [ -z "$(find $MNT -name .jffs_sync)" ]; then
    logger -s "Cloning JFFS to USB. ($1)"
    mkdir $MNT/.jffs_sync
    cp -pr /jffs/* $MNT/jffs/
    echo $(mount | grep /jffs | awk '{print $1}' ) > $MNT/.jffs_sync/orig_jffs.map
    echo $(ls -l $MNT/jffs/scripts | md5sum) > $MNT/.jffs_sync/scripts.md5
    echo $(ls -l $MNT/jffs/configs | md5sum) > $MNT/.jffs_sync/configs.md5
fi

update_folder ()
{
    DEPTH=$(echo $1 | grep -o "/" | wc -l)
    DEPTH=$((DEPTH+1))
    DEST=$(echo $1 | cut -d'/' -f${DEPTH} )
    LAST=$(cat $MNT/.jffs_sync/$DEST.md5 2>/dev/null)
    CUR=$(ls -l $MNT/jffs/$DEST | md5sum)

    if [ "$CUR" == "$LAST" ]; then
        return
    fi

    # Update files from USB to JFFS.
    for FILE in $(ls $1); do
        USB_FILE=$(md5sum $1/$FILE 2>/dev/null | awk '{print $1}')
        JFFS_FILE=$(md5sum /jffs/$DEST/$FILE 2>/dev/null | awk '{print $1}')

        if [ "$USB_FILE" != "$JFFS_FILE" ]; then
            logger -s "USB->JFFS Sync: Copying $1/$FILE to /jffs/$DEST."
                    cp -pf $1/$FILE /jffs/$DEST/
            if [ "$DEST" == "scripts" ]; then
                chmod a+x /jffs/$DEST/$FILE
            fi
        fi
    done

    # Remove files not found on USB.
    for FILE in $(ls /jffs/$DEST); do
        if [ -z "$(find $1/$FILE 2>/dev/null)" ]; then
            logger -s "USB->JFFS Sync: Erasing '$FILE' from /jffs/$DEST."
            rm -rf /jffs/$DEST/$FILE
        fi
    done
    echo $(ls -l /jffs/$DEST | md5sum) > $MNT/.jffs_sync/$DEST.md5
}

update_folder $MNT/jffs/scripts
update_folder $MNT/jffs/configs

# If this is not an unmount, unmount jffs and remount the usb jffs.
if [ -z $(echo "$0" | grep "unmount") ]; then
   umount -l /jffs
   mount -o rbind $1/jffs /jffs
   sleep 3
   sync
   sleep 1
   echo 3 > /proc/sys/vm/drop_caches
fi

