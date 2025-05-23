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
PROFILE_EMAIL_SMTP_HOSTNAME=""

## @todo Does not work on OS X -- flag "-f" does not exist there.
SCRIPT_PATH=$(readlink -f $0 | xargs dirname)
SCRIPT_EXITCODE=0


cleanup()
{
    MY_TRAP_ERR=$?

    trap '' EXIT INT TERM

    ${ECHO} "Cleaning up ..."

    if [ -n "$BACKUP_LOCKFILE" ]; then
        rm "$BACKUP_LOCKFILE"
    fi

    # Make sure that we unset the password, no matter if we defined it or not.
    unset $RESTIC_PASSWORD

    exit $MY_TRAP_ERR
}

sig_cleanup()
{
    trap '' EXIT # Some shells will call EXIT after the INT handler
    false # Sets $?
    cleanup
}

backup_detect_mail()
{
    # Detect mail agent to use, try s-nail first.
    SCRIPT_MAIL_BIN=$(which s-nail)
    if [ ! -x ${SCRIPT_MAIL_BIN} ]; then
        # Check if mailx is the heirloom-mailx version which supports more
        # features like -S for the SMTP stuff.
        #
        ## @todo For now we ASSUME that only the heirloom version (-V) returns
        #        an exit code 0, whereas the dumb versions don't.
        SCRIPT_MAIL_BIN=mailx
        if [ -x ${SCRIPT_MAIL_BIN} ]; then
            ${SCRIPT_MAIL_BIN} -V 2>&1 > /dev/null
            if [ $? -ne "0" ]; then
                SCRIPT_MAIL_BIN=heirloom-mailx
                ${SCRIPT_MAIL_BIN} -V 2>&1 > /dev/null
                if [ $? -ne "0" ]; then
                    SCRIPT_MAIL_BIN=
                fi
            fi
        fi
    fi

    if [ -n "$SCRIPT_MAIL_BIN" ]; then
        ${ECHO} "Mail client found: $SCRIPT_MAIL_BIN"
    fi
}

backup_send_email()
{
    if [ -z "$SCRIPT_MAIL_BIN" ]; then
        backup_log "No (valid) mail client found, skipping to send e-mail"
        return
    fi

    MY_SNAIL_MTA=${PROFILE_EMAIL_USERNAME}:${PROFILE_EMAIL_PASSWORD}@${PROFILE_EMAIL_SMTP_HOSTNAME}
    MY_SNAIL_MTA_ENC_USER=$(printf %s "${PROFILE_EMAIL_USERNAME}" | jq -sRr @uri)
    MY_SNAIL_MTA_ENC_HOSTNAME=$(printf %s "${PROFILE_EMAIL_SMTP_HOSTNAME}" | jq -sRr @uri)

    # jq 1.6 did not percent encode all reserved characters such as '!', '*', '(') and ')'
    # So passwords must be encoded by hand for now.
    # MY_SNAIL_MTA_ENC_PASSWORD=$(printf %s "${PROFILE_EMAIL_PASSWORD}" | jq -sRr @uri)
    MY_SNAIL_MTA_ENC_PASSWORD=${PROFILE_EMAIL_PASSWORD}
    echo "Note: Workaround for jq <= 1.6 active for passwords!"

    echo "$2" | env LC_ALL=C ${SCRIPT_MAIL_BIN} -:/ \
        -s "$1" \
        -S v15-compat \
        -S mta=smtps://${MY_SNAIL_MTA_ENC_USER}:${MY_SNAIL_MTA_ENC_PASSWORD}@${MY_SNAIL_MTA_ENC_HOSTNAME} \
        -S smtp-auth=login \
        -S from="$PROFILE_EMAIL_FROM_ADDRESS" \
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

    if [ ${PROFILE_EMAIL_ENABLED} -gt "0" ]; then
        if [ -n "$SCRIPT_MAIL_BIN" ]; then
            backup_log "mail client found, trying to send test mail ..."
            backup_send_email "Backup TEST: $PROFILE_NAME" "The mail test for '$PROFILE_NAME' was successful. Have a nice day."
        else
            backup_log "No mail client found / installed, skipping mail test"
        fi
    else
        backup_log "Sending mail not configured, skipping mail test"
    fi
}

backup_update()
{
    LOCAL_RESTIC_TAG_LATEST=$(curl --silent "https://api.github.com/repos/restic/restic/releases/latest" | grep -Po '"tag_name": "v\K.*?(?=")')
    echo "Downloading and installing restic v$LOCAL_RESTIC_TAG_LATEST ..."
    LOCAL_RESTIC_URL=https://github.com/restic/restic/releases/download/v${LOCAL_RESTIC_TAG_LATEST}/restic_${LOCAL_RESTIC_TAG_LATEST}_linux_amd64.bz2
    sudo curl -L --silent ${LOCAL_RESTIC_URL} | bunzip2 > /usr/local/bin/restic
    sudo chmod 755 /usr/local/bin/restic
    return $?
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

    CUR_DEST_DIR=${BACKUP_PATH_PREFIX}${LOCAL_DEST_DIR}/
    CUR_LOG_NAME=${BACKUP_PATH_TMP}/${BACKUP_LOG_PREFIX}-${PROFILE_NAME}
    CUR_LOG_FILE=${CUR_LOG_NAME}.log

    ${ECHO} "Backing up: $PROFILE_NAME"
    ${ECHO} "    Target: $CUR_DEST_DIR"
    ${ECHO} "       Log: $CUR_LOG_FILE"

    export RESTIC_PASSWORD=${PROFILE_GPG_PASSPHRASE}

    # Init the repository in case it doesn't exist (yet).
    ${BACKUP_BIN} init -r ${CUR_DEST_DIR} > /dev/null 2>&1

    LOCAL_BACKUP_OPTS="\
        backup \
        -v \
        --exclude-caches \
        --one-file-system"

    if [ -n "$PROFILE_SOURCES_MONTHLY_EXCLUDE" ]; then
        for CUR_EXCLUDE in ${PROFILE_SOURCES_MONTHLY_EXCLUDE}; do
            LOCAL_BACKUP_OPTS="$LOCAL_BACKUP_OPTS --exclude $CUR_EXCLUDE"
        done
    fi

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

# Install trap handlers.
trap cleanup EXIT
trap sig_cleanup INT QUIT TERM

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
    update)
        backup_update
        exit $?
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

backup_detect_mail

${ECHO} "Using profile: $SCRIPT_PROFILE_FILE_ABS"
. ${SCRIPT_PROFILE_FILE_ABS}

if [ -z "$PROFILE_GPG_PASSPHRASE" ]; then
    ${ECHO} "No passphrase (PROFILE_GPG_PASSPHRASE) set, cannot continue. Aborting."
    exit 1
fi

BACKUP_LOCKFILE=/tmp/backup-${PROFILE_NAME}.lock
if [ -f "$BACKUP_LOCKFILE" ]; then
    ${ECHO} "Backup already running."
    exit 1
fi
touch "$BACKUP_LOCKFILE"

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
        BACKUP_PATH_PREFIX=sftp:${BACKUP_DEST_HOST}:${PROFILE_DEST_SSH_PORT}:
        RSYNC_PATH_PREFIX=${BACKUP_DEST_HOST}:
    else
        BACKUP_PATH_PREFIX=sftp:${BACKUP_DEST_HOST}:
        RSYNC_PATH_PREFIX=${BACKUP_DEST_HOST}:${PROFILE_DEST_SSH_PORT}:
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
        export RESTIC_PASSWORD=${PROFILE_GPG_PASSPHRASE}
        ${BACKUP_BIN} -v check -r ${BACKUP_PATH_PREFIX}/${BACKUP_DEST_DIR_MONTHLY}/${LOCAL_REPO_NAME}
        unset RESTIC_PASSWORD
        ;;
    repo-verify)
        export RESTIC_PASSWORD=${PROFILE_GPG_PASSPHRASE}
        ${BACKUP_BIN} -v check --read-data -r ${BACKUP_PATH_PREFIX}/${BACKUP_DEST_DIR_MONTHLY}/${LOCAL_REPO_NAME}
        unset RESTIC_PASSWORD
        ;;
    test)
        backup_test
        if [ $? -ne "0" ]; then
            SCRIPT_EXITCODE=1
            break
        fi
        ;;
    setup)
        backup_update
        backup_setup
        if [ $? -ne "0" ]; then
            SCRIPT_EXITCODE=1
            break
        fi
        ;;
    update)
        backup_update
        ;;
    *)
        ${ECHO} "Unknown command \"$SCRIPT_CMD\", exiting"
        SCRIPT_EXITCODE=1
        ;;
esac

exit ${SCRIPT_EXITCODE}
