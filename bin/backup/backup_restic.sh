#!/bin/sh

# Copyright 2015-2018 by Andreas Loeffler (x86dev).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

BACKUP_BIN=restic
BASENAME=basename
CHMOD=chmod
CP=cp
DATE=date
ECHO=echo
GPG=gpg
MAILX=$(which mailx)
MKDIR=mkdir
MV=mv
RM=rm
RSYNC=rsync
SCP=scp
SED=sed
SSH_COPY_ID=ssh-copy-id
SSH_KEYGEN=ssh-keygen
SSH=ssh
TEE=tee

#
# Set defaults.
#
PROFILE_NAME="<Unnamed>"

PROFILE_SOURCES_MONTHLY=""
PROFILE_SOURCES_ONCE=""

PROFILE_DEST_HOST="localhost"
PROFILE_DEST_SSH_PORT=22
PROFILE_DEST_SSH_IDENTITY_FILE=
PROFILE_DEST_USERNAME=$USER
PROFILE_DEST_DIR="/tmp"

PROFILE_GPG_KEY=""
PROFILE_GPG_PASSPHRASE=""

PROFILE_EMAIL_ENABLED=0
PROFILE_EMAIL_FROM_ADDRESS=""
PROFILE_EMAIL_SMTP=""

## @todo Does not work on OS X -- flag "-f" does not exist there.
SCRIPT_PATH=$(readlink -f $0 | xargs dirname)
SCRIPT_EXITCODE=0
SCRIPT_HAS_MAILX=0


backup_send_email()
{
    if [ "$SCRIPT_HAS_MAILX" = "0" ]; then
        return
    fi

    echo "$2" | ${MAILX} \
        -s "$1" \
        -S from="$PROFILE_EMAIL_FROM_ADDRESS" \
        -S smtp="$PROFILE_EMAIL_SMTP" \
        -S smtp-use-starttls \
        -S smtp-auth=login \
        -S smtp-auth-user="$PROFILE_EMAIL_USERNAME" \
        -S smtp-auth-password="$PROFILE_EMAIL_PASSWORD" \
        -S ssl-verify=strict \
        ${PROFILE_EMAIL_TO_ADDRESS}
}

backup_send_email_start()
{
    EMAIL_SUBJECT="Backup started: $PROFILE_NAME"
    EMAIL_BODY="Backup has been started.

    Profile: $PROFILE_NAME

    Monthly tasks:
        $PROFILE_SOURCES_MONTHLY

    Mirror tasks:
        $PROFILE_SOURCES_ONCE

    Started on: $($DATE)

    ---"

    if [ ${PROFILE_EMAIL_ENABLED} -gt "1" ]; then
        backup_send_email "$EMAIL_SUBJECT" "$EMAIL_BODY"
    fi
}

backup_send_email_success()
{
    EMAIL_SUBJECT="Backup successful: $PROFILE_NAME"
    EMAIL_BODY="Backup successfully finished.

    Profile: $PROFILE_NAME

    Monthly tasks:
        $PROFILE_SOURCES_MONTHLY

    Mirror tasks:
        $PROFILE_SOURCES_ONCE

    Started on: $($DATE)
    Duration  : $SCRIPT_TEXT_DURATION

    ---"

    if [ ${PROFILE_EMAIL_ENABLED} -gt "1" ]; then
        backup_send_email "$EMAIL_SUBJECT" "$EMAIL_BODY"
    fi
}

backup_send_email_failure()
{
    EMAIL_SUBJECT="Backup FAILED: $PROFILE_NAME"
    EMAIL_BODY="*** BACKUP FAILED (See details in log below) ***

    Profile   : $PROFILE_NAME
    Started at: $($DATE)
    Duration  : $SCRIPT_TEXT_DURATION

    ---

    <TODO: Implement sending logfile>

    ---
    "

    EMAIL_DF=$(df -H | grep -vE '^Filesystem|tmpfs|cdrom')
    EMAIL_BODY="$EMAIL_BODY\n\n$EMAIL_DF"

    if [ ${PROFILE_EMAIL_ENABLED} -gt "0" ]; then
        backup_send_email "$EMAIL_SUBJECT" "$EMAIL_BODY"
    fi
}

backup_log()
{
    ${ECHO} "$1"
}

backup_test()
{
    backup_log "Testing profile '$PROFILE_NAME' ..."

    # Check if mailx is the heirloom-mailx version which supports more
    # features like -S for the SMTP stuff.
    #
    ## @todo For now we ASSUME that only the heirloom version (-V) returns
    #        an exit code 0, whereas the dumb versions don't.
    if [ ${PROFILE_EMAIL_ENABLED} -gt "0" ]; then
        if [ "$SCRIPT_HAS_MAILX" = "1" ]; then
            ${MAILX} -V 2>&1 > /dev/null
            if [ $? -ne "0" ]; then
                backup_log "Either wrong or old mailx version installed, aborting."
                return 1
            fi

            backup_log "mailx found, trying to send test mail ..."
            backup_send_email "Backup TEST: $PROFILE_NAME" "The mail test for '$PROFILE_NAME' was successful. Have a nice day."
        else
            backup_log "No mailx found / installed, skipping mail test"
        fi
    else
        backup_log "Sending mail not configured, skipping mail test"
    fi
}

backup_setup()
{
    #${ECHO} "Testing key: ${PROFILE_GPG_KEY}"
    #${ECHO} "1234" | ${GPG} --no-use-agent -o /dev/null --local-user ${PROFILE_GPG_KEY} -as - && echo "The correct passphrase was entered for your key."

    LOCAL_RC=0
    ${ECHO} "Setting up ..."

    LOCAL_KEYFILE=${HOME}/.ssh/id_backup_${PROFILE_NAME}
    if [ ! -f ${LOCAL_KEYFILE} ]; then
        ${SSH_KEYGEN} -t rsa -N "" -f ${LOCAL_KEYFILE}
        if [ $? -ne "0" ]; then
            ${CHMOD} 600 ${LOCAL_KEYFILE}
        fi
    fi

    if [ $LOCAL_RC -eq "0" ]; then
        ${ECHO} "Installing SSH key to backup target $BACKUP_DEST_HOST ..."
        ${SSH_COPY_ID} -i ${LOCAL_KEYFILE} ${BACKUP_DEST_HOST}
        if [ $? -ne "0" ]; then
            ${ECHO} "Error installing SSH key to backup target!"
            LOCAL_RC=1
        else
            ${SSH} ${BACKUP_DEST_HOST} 'exit'
            if [ $? -ne "0" ]; then
                echo "Error testing SSH login!"
                LOCAL_RC=1
            fi
        fi
    fi

    if [ $LOCAL_RC -eq "0" ]; then
        ${ECHO} "Setup successful."
    fi

    return ${LOCAL_RC}
}

backup_create_dir()
{
    LOCAL_RC=0
    if [ "$BACKUP_TO_REMOTE" = "1" ]; then
        backup_log "Creating remote directory: '$2'"
        ${SSH} ${BACKUP_SSH_OPTS} ${BACKUP_DEST_HOST} "mkdir -p $2"
        if [ $? -ne "0" ]; then
            backup_log "Creating remote directory '$2' failed"
            LOCAL_RC=1
        fi
    else
        backup_log "Creating local directory: '$2'"
        ${MKDIR} -p "$2"
        if [ $? -ne "0" ]; then
            backup_log "Creating local directory '$2' failed"
            LOCAL_RC=1
        fi
    fi

    return ${LOCAL_RC}
}

backup_copy_file()
{
    LOCAL_RC=0
    if [ "$BACKUP_TO_REMOTE" = "1" ]; then
        LOCAL_FILE=${BACKUP_DEST_HOST}:${2}/$($BASENAME ${1})
        backup_log "Copying file '$1' to remote '$LOCAL_FILE'"
        ${SCP} ${BACKUP_SCP_OPTS} "$1" "$LOCAL_FILE"
        if [ $? -ne "0" ]; then
            LOCAL_RC=1
        fi
    else
        backup_log "Copying file '$1' to '$2'"
        ${CP} "$1" "$2"
        if [ $? -ne "0" ]; then
            LOCAL_RC=1
        fi
    fi

    return ${LOCAL_RC}
}

backup_run()
{
    LOCAL_RC=0

    LOCAL_HOST=${1}
    LOCAL_SOURCES=${2}
    LOCAL_DEST_DIR=${3}

    backup_create_dir "$LOCAL_HOST" "$LOCAL_DEST_DIR"

    LOCAL_BACKUP_OPTS="\
        backup \
        -v \
        --exclude-caches \
        --one-file-system"

    export RESTIC_PASSWORD=${PROFILE_GPG_PASSPHRASE}

    CUR_DEST_DIR=${BACKUP_PATH_PREFIX}:${LOCAL_DEST_DIR}/
    CUR_LOG_NAME=${BACKUP_PATH_TMP}/${BACKUP_LOG_PREFIX}-${PROFILE_NAME}
    CUR_LOG_FILE=${CUR_LOG_NAME}.log
    ${ECHO} "Backing up: $PROFILE_NAME"
    ${ECHO} "    Target: $CUR_DEST_DIR"
    ${ECHO} "       Log: $CUR_LOG_FILE"
    ${BACKUP_BIN} -r ${CUR_DEST_DIR} ${LOCAL_BACKUP_OPTS} ${LOCAL_SOURCES} | tee -a ${CUR_LOG_FILE}
    if [ $? -ne "0" ]; then
        backup_log "Failed running backup (see $CUR_LOG_FILE)"
        LOCAL_RC=1
    fi
    backup_copy_file "$CUR_LOG_FILE" "$LOCAL_DEST_DIR"

    unset RESTIC_PASSWORD

    return ${LOCAL_RC}
}

rsync_run()
{
    LOCAL_RC=0

    LOCAL_RSYNC_BIN=rsync
    LOCAL_RSYNC_OPTS="\
        --archive \
        --delete \
        --stats"

    LOCAL_HOST=${1}
    LOCAL_SOURCES=${2}
    LOCAL_DEST_DIR=${3}

    for CUR_SOURCE in ${LOCAL_SOURCES}; do
        CUR_SOURCE_SUFFIX=$($ECHO ${CUR_SOURCE} | ${SED} 's_/_-_g')
        CUR_DEST_DIR=${LOCAL_DEST_DIR}/${PROFILE_NAME}${CUR_SOURCE_SUFFIX}/
        CUR_LOG_FILE_SUFFIX=$($ECHO ${CUR_SOURCE}.log | ${SED} 's_/_-_g')
        CUR_LOG_FILE=${BACKUP_PATH_TMP}/${BACKUP_LOG_PREFIX}-${PROFILE_NAME}${CUR_LOG_FILE_SUFFIX}
        ${ECHO} "Mirroring: $CUR_SOURCE"
        ${ECHO} "       To: $CUR_DEST_DIR"
        ${ECHO} "      Log: $CUR_LOG_FILE"
        backup_create_dir "$LOCAL_HOST" "$CUR_DEST_DIR"
        ${LOCAL_RSYNC_BIN} ${LOCAL_RSYNC_OPTS} ${CUR_SOURCE} ${RSYNC_PATH_PREFIX}${CUR_DEST_DIR} > ${CUR_LOG_FILE} 2>&1
        if [ $? -ne "0" ]; then
            backup_log "Failed running Rsync for source '$CUR_SOURCE' (see $CUR_LOG_FILE)"
            LOCAL_RC=1
        fi
        backup_copy_file "$CUR_LOG_FILE" "$CUR_DEST_DIR"
    done

    return $LOCAL_RC
}

backup_debian()
{
    dpkg --get-selections > dpkg-selections-$(date -I)
    dpkg --set-selections < dpkg-selections-$(date -I)
}

show_help()
{
    ${ECHO} "Simple backup script for doing monthly and one-time backups."
    ${ECHO} "Requires $BACKUP_BIN and rsync."
    ${ECHO} ""
    ${ECHO} "Usage: $0 [--help|-h|-?]"
    ${ECHO} "       backup|test"
    ${ECHO} "       [--profile <profile.conf>]"
    ${ECHO} ""
    exit 1
}

if [ $# -lt 1 ]; then
    ${ECHO} "ERROR: No main command given" 1>&2
    ${ECHO} "" 1>&2
    show_help
fi

SCRIPT_CMD="$1"
shift
case "$SCRIPT_CMD" in
    backup)
        ;;
    repo-status)
        ;;
    repo-verify)
        ;;
    setup)
        ;;
    test)
        ;;
    --help|-h|-?)
        show_help
        ;;
    *)
        echo "ERROR: Unknown main command \"$SCRIPT_CMD\"" 1>&2
        echo "" 1>&2
        show_help
        ;;
esac

while [ $# != 0 ]; do
    CUR_PARM="$1"
    shift
    case "$CUR_PARM" in
        --profile)
            SCRIPT_PROFILE_FILE="$1"
            shift
            ;;
        --help|-h|-?)
            show_help
            ;;
        *)
            ${ECHO} "ERROR: Unknown option \"$CUR_PARM\"" 1>&2
            ${ECHO} "" 1>&2
            show_help
            ;;
    esac
done

if [ -z "$SCRIPT_PROFILE_FILE" ]; then
    ${ECHO} "ERROR: Must specify a profile name using --profile (e.g. --profile /path/to/profile.conf), exiting"
    exit 1
fi

# First, see if the profile file is a relative path.
SCRIPT_PROFILE_FILE_ABS=${SCRIPT_PATH}/${SCRIPT_PROFILE_FILE}
if [ ! -f "$SCRIPT_PROFILE_FILE_ABS" ]; then
    # Not found -- must be an absolute path then.
    SCRIPT_PROFILE_FILE_ABS=${SCRIPT_PROFILE_FILE}
    if [ ! -f "$SCRIPT_PROFILE_FILE_ABS" ]; then
        ${ECHO} "Profile \"$SCRIPT_PROFILE_FILE_ABS\" not found, exiting"
        exit 1
    fi
fi

SCRIPT_TS_START=$($DATE +%s)

# Detect mailx.
if [ -x ${MAILX} ]; then
    SCRIPT_HAS_MAILX=1
fi

${ECHO} "Using profile: $SCRIPT_PROFILE_FILE_ABS"
. ${SCRIPT_PROFILE_FILE_ABS}

if [ -z "$PROFILE_GPG_PASSPHRASE" ]; then
    ${ECHO} "No passphrase (PROFILE_GPG_PASSPHRASE) set, cannot continue. Aborting."
    exit 1
fi

if [ "$PROFILE_DEST_HOST" = "localhost" ]; then
    BACKUP_TO_REMOTE=0
else
    BACKUP_TO_REMOTE=1
fi

if [ -n "$PROFILE_DEST_SSH_PORT" ]; then
    BACKUP_SCP_OPTS="-q -P $PROFILE_DEST_SSH_PORT"
    BACKUP_SSH_OPTS="-p $PROFILE_DEST_SSH_PORT"
fi

BACKUP_PATH_TMP=/tmp
${ECHO} "Using temp dir: $BACKUP_PATH_TMP"

if [ "$BACKUP_TO_REMOTE" = "1" ]; then
    if [ -n "$PROFILE_DEST_USERNAME" ]; then
        BACKUP_DEST_HOST=${PROFILE_DEST_USERNAME}@${PROFILE_DEST_HOST}
    else
        BACKUP_DEST_HOST=${PROFILE_DEST_HOST}
    fi
    if [ -n "$PROFILE_DEST_SSH_PORT" ]; then
        BACKUP_PATH_PREFIX=sftp:${BACKUP_DEST_HOST}:${PROFILE_DEST_SSH_PORT}
        RSYNC_PATH_PREFIX=${BACKUP_DEST_HOST}:
    else
        BACKUP_PATH_PREFIX=sftp:${BACKUP_DEST_HOST}
        RSYNC_PATH_PREFIX=${BACKUP_DEST_HOST}:${PROFILE_DEST_SSH_PORT}
    fi
else
    BACKUP_DEST_HOST=localhost
    BACKUP_PATH_PREFIX=
    RSYNC_PATH_PREFIX=
fi

BACKUP_DEST_DIR=${PROFILE_DEST_DIR}
BACKUP_DEST_DIR_MONTHLY="${BACKUP_DEST_DIR}/backup_$(date +%y%m)"

BACKUP_TIMESTAMP=$(date "+%Y-%m-%d_%H%M%S")
BACKUP_LOG_PREFIX="backup-$BACKUP_TIMESTAMP"

case "$SCRIPT_CMD" in
    backup)
        LANG_OLD=${LANG}
        export LANG=en_US.UTF-8
        unset PASSPHRASE
        backup_send_email_start
        backup_log "Backup started at: $(date --rfc-3339=seconds)"
        backup_log "Running monthly backups ..."
        backup_create_dir "$BACKUP_DEST_HOST" "$BACKUP_DEST_DIR"
        if [ $? -ne "0" ]; then
            SCRIPT_EXITCODE=1
            break
        fi
        backup_create_dir "$BACKUP_DEST_HOST" "$BACKUP_DEST_DIR_MONTHLY"
        if [ $? -ne "0" ]; then
            SCRIPT_EXITCODE=1
            break
        fi
        backup_run "$BACKUP_DEST_HOST" "$PROFILE_SOURCES_MONTHLY" "$BACKUP_DEST_DIR_MONTHLY"
        if [ $? -ne "0" ]; then
            SCRIPT_EXITCODE=1
            break
        fi
        export LANG=${LANG_OLD}
        if [ -n "$PROFILE_SOURCES_ONCE" ]; then
            backup_log "Running only-once backups (mirroring) ..."
            rsync_run "$BACKUP_DEST_HOST" "$PROFILE_SOURCES_ONCE" "$BACKUP_DEST_DIR"
            if [ $? -ne "0" ]; then
                SCRIPT_EXITCODE=1
                break
            fi
        fi

        SCRIPT_TS_END=$($DATE +%s)
        SCRIPT_TS_DIFF_SECONDS=$(($SCRIPT_TS_END - $SCRIPT_TS_START))
        SCRIPT_TS_DIFF_MINS=$(($SCRIPT_TS_DIFF_SECONDS / 60))
        if [ $SCRIPT_TS_DIFF_MINS -eq "0" ]; then
            SCRIPT_TEXT_DURATION="$SCRIPT_TS_DIFF_SECONDS seconds"
        else
            SCRIPT_TEXT_DURATION="$SCRIPT_TS_DIFF_MINS minute(s)"
        fi

        if [ ${SCRIPT_EXITCODE} = "0" ]; then
            backup_log "Backup successfully finished."
            if [ ${PROFILE_EMAIL_ENABLED} -gt "1" ]; then
                backup_send_email_success
            fi
        else
            backup_log "Backup FAILED!"
            if [ ${PROFILE_EMAIL_ENABLED} -gt "0" ]; then
                backup_send_email_failure
            fi
        fi
        backup_log "Backup ended at: $(date --rfc-3339=seconds)"
        ;;
    repo-status)
        ${BACKUP_BIN} -v check ${BACKUP_PATH_PREFIX}/${BACKUP_DEST_DIR_MONTHLY}/${LOCAL_REPO_NAME}
        ;;
    repo-verify)
        ;;
    test)
        backup_test
        if [ $? -ne "0" ]; then
            SCRIPT_EXITCODE=1
            break
        fi
        ;;
    setup)
        backup_setup
        if [ $? -ne "0" ]; then
            SCRIPT_EXITCODE=1
            break
        fi
        ;;
    *)
        ${ECHO} "Unknown command \"$SCRIPT_CMD\", exiting"
        SCRIPT_EXITCODE=1
        ;;
esac


exit ${SCRIPT_EXITCODE}
