#!/bin/sh

VERSION=0.0.2
lastLogfile="/var/log/backup-last.log"
lastMailLogfile="/var/log/mail-last.log"
lastMicrosoftTeamsLogfile="/var/log/microsoft-teams-last.log"

version() {
  echo $VERSION
  exit 0
}
copyErrorLog() {
  cp ${lastLogfile} /var/log/backup-error-last.log
}

logLast() {
  echo "$1" >> ${lastLogfile}
}

if [ "$1" = "version" ]; then
    version
fi

if [ -f "/hooks/pre-backup.sh" ]; then
    echo "Starting pre-backup script ..."
    /hooks/pre-backup.sh
else
    echo "Pre-backup script not found ..."
fi

start=`date +%s`
rm -f ${lastLogfile} ${lastMailLogfile}
echo "Starting Backup at $(date +"%Y-%m-%d %H:%M:%S")"
echo "Starting Backup at $(date)" >> ${lastLogfile}
logLast "BACKUP_CRON: ${BACKUP_CRON}"
logLast "RESTIC_TAG: ${RESTIC_TAG}"
logLast "RESTIC_FORGET_ARGS: ${RESTIC_FORGET_ARGS}"
logLast "RESTIC_JOB_ARGS: ${RESTIC_JOB_ARGS}"
logLast "RESTIC_REPOSITORY: ${RESTIC_REPOSITORY}"
logLast "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}"

# Do not save full backup log to logfile but to backup-last.log
restic backup /data ${RESTIC_JOB_ARGS} --tag=${RESTIC_TAG?"Missing environment variable RESTIC_TAG"} >> ${lastLogfile} 2>&1
backupRC=$?
logLast "Finished backup at $(date)"
if [[ $backupRC == 0 ]]; then
    echo "Backup Successfull"
else
    echo "Backup Failed with Status ${backupRC}"
    restic unlock
    copyErrorLog
fi

if [[ $backupRC == 0 ]] && [ -n "${RESTIC_FORGET_ARGS}" ]; then
    echo "Forget about old snapshots based on RESTIC_FORGET_ARGS = ${RESTIC_FORGET_ARGS}"
    restic forget ${RESTIC_FORGET_ARGS} >> ${lastLogfile} 2>&1
    rc=$?
    logLast "Finished forget at $(date)"
    if [[ $rc == 0 ]]; then
        echo "Forget Successfull"
    else
        echo "Forget Failed with Status ${rc}"
        restic unlock
        copyErrorLog
    fi
fi

end=`date +%s`
echo "Finished Backup at $(date +"%Y-%m-%d %H:%M:%S") after $((end-start)) seconds"

if [ -f "/hooks/post-backup.sh" ]; then
    echo "Starting post-backup script ..."
    /hooks/post-backup.sh $backupRC
else
    echo "Post-backup script not found ..."
fi
