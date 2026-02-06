#! /bin/bash


#wget https://mega.nz/linux/repo/xUbuntu_20.04/amd64/megacmd-xUbuntu_20.04_amd64.deb && sudo apt install "$PWD/megacmd-xUbuntu_20.04_amd64.deb"

#в файле  прописан логин пароль
day=$(date +%Y_%m_%d-%H%M)
CLOUD_BACKUPS_DIR="_DTRAFO_VPN_"
LOCAL_BACKUPS_DIR="/tmp/${CLOUD_BACKUPS_DIR}"
NAMEARH=sys_$CLOUD_BACKUPS_DIR
fname=${day}-${NAMEARH}
BACKUP_COUNT=24; #The default value for the number of backups


_MEGA_USER=vlan003@bk.ru
_MEGA_PASS=XXXXX-XXXXX


mkdir /tmp/${fname}
mkdir ${LOCAL_BACKUPS_DIR}

cp -r /etc /tmp/${fname}/
crontab -l > /tmp/${fname}/cron.txt
tar cfz ${LOCAL_BACKUPS_DIR}/${fname}.tar.gz /tmp/$fname
rm -r /tmp/${fname}


mega-login ${_MEGA_USER}  ${_MEGA_PASS}
mega-cd /
mega-mkdir /${CLOUD_BACKUPS_DIR}

#Upload backups
#Remove old backups
echo "[$(date +%F" "%T)] -- Start remove $USER cloud backups:"
   while [ $(mega-ls  /${CLOUD_BACKUPS_DIR} |  grep -E "${NAMEARH}.tar.gz" | wc -l) -gt ${BACKUP_COUNT} ]
     do
        TO_REMOVE=$(mega-ls  /${CLOUD_BACKUPS_DIR} | grep -E "${NAMEARH}.tar.gz" | sort | head -n 1)
        echo "[$(date +%F" "%T)] -- Remove file: mega-:$TO_REMOVE"
        mega-rm /${CLOUD_BACKUPS_DIR}/${TO_REMOVE}
     done

echo "[$(date +%F" "%T)] -- Stop remove $USER cloud backups"
echo "[$(date +%F" "%T)] -- Start upload $USER backups:"

mega-cd  /${CLOUD_BACKUPS_DIR}

     FILES=$(/usr/bin/find  ${LOCAL_BACKUPS_DIR}  -type f -name "*.tar.gz"  | sort );
     for FILE in ${FILES}; do
         FILENAME=${FILE##*/}
#         echo "[$(date +%F" "%T)] -- Upload: $FILE"
         mega-put -c "${LOCAL_BACKUPS_DIR}/${FILENAME}" "/${CLOUD_BACKUPS_DIR}/"
     done
echo "[$(date +%F" "%T)] -- Stop upload $USER backups"
echo "[$(date +%F" "%T)]"

rm -r  ${LOCAL_BACKUPS_DIR}
mega-logout
