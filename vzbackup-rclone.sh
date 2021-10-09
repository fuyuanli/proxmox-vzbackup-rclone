#!/bin/bash
# ./vzbackup-rclone.sh rehydrate YYYY/MM/DD file_name_encrypted.bin

############ /START CONFIG
dumpdir="/var/lib/vz/dump" # Set this to where your vzdump files are stored
MAX_AGE=3 # This is the age in days to keep local backup copies. Local backups older than this are deleted.
############ /END CONFIG

_bdir="$dumpdir"
rcloneroot="$dumpdir/rclone"
timepath="$(date +%Y)/$(date +%m)"
rclonedir="$rcloneroot/$timepath"
COMMAND=${1}
rehydrate=${2} #enter the date you want to rehydrate in the following format: YYYY/MM/DD
if [ ! -z "${3}" ];then
        CMDARCHIVE=$(echo "/${3}" | sed -e 's/\(.bin\)*$//g')
fi
tarfile=${TARGET}
exten=${tarfile#*.}
filename=${tarfile%.*.*}

if [[ ${COMMAND} == 'rehydrate' ]]; then
    #echo "Please enter the date you want to rehydrate in the following format: YYYY/MM/DD"
    #echo "For example, today would be: $timepath"
    #read -p 'Rehydrate Date => ' rehydrate
    rclone --config /root/.config/rclone/rclone.conf \
    --drive-chunk-size=32M copy gd-backup_crypt:/$rehydrate$CMDARCHIVE $dumpdir \
    -v --stats=60s --transfers=16 --checkers=16
fi

if [[ ${COMMAND} == 'job-start' ]]; then
#    echo "Deleting backups older than $MAX_AGE days."
#    find $dumpdir -type f -mtime +$MAX_AGE -exec /bin/rm -f {} \;
    echo "Backup VM/LXC with Rclone"
fi

if [[ ${COMMAND} == 'backup-end' ]]; then
    echo "Backing up $tarfile to remote storage"
    #mkdir -p $rclonedir
    #cp -v $tarfile $rclonedir
    echo "rcloning $rclonedir"
    #ls $rclonedir
    rclone --config /root/.config/rclone/rclone.conf \
    --drive-chunk-size=32M copy $tarfile gd-backup_crypt:/$timepath/vzdump \
    -v --stats=60s --transfers=16 --checkers=16
fi

if [[ ${COMMAND} == 'job-end' ||  ${COMMAND} == 'job-abort' ]]; then
    echo "Backing up main PVE configs"
    _tdir=${TMP_DIR:-/var/tmp}
    _tdir=$(mktemp -d $_tdir/proxmox-XXXXXXXX)
    function clean_up {
        echo "Cleaning up"
        rm -rf $_tdir
    }
    trap clean_up EXIT
    _now=$(date +%Y-%m-%d.%H.%M.%S)
    _HOSTNAME=$(hostname -f)
    _filename1="$_tdir/pveConfig.$_now.tgz"

    echo "Tar files"
    # copy key system files
    tar --warning='no-file-ignored' -zcPf "$_filename1" /etc/pve/.
    echo "rcloning $_filename1"
    #ls $rclonedir
    rclone --config /root/.config/rclone/rclone.conf \
    --drive-chunk-size=32M move $_filename1 gd-backup_crypt:/$timepath/pveconfig \
    -v --stats=60s --transfers=16 --checkers=16

fi
