#!/usr/bin/env sh
# profile based rsync-time-backup
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

# Print CLI usage help
fn_display_usage () {
	echo "Usage: rtb-wrapper.sh <action> <profile>"
	echo ""
	echo "action: backup, restore"
	echo "profile: name of the profile file"
	echo ""
	echo "For more detailed help, please see the README file:"
	echo ""
	echo "https://github.com/thomas-mc-work/rtb-wrapper/blob/master/README.md"
}

fn_parse_ssh_flags() {
    cmd=""
    if [ -n "${SSH_PORT:-}" ]; then
        cmd="-p ${SSH_PORT}"
    fi

    if [ -n "${ID_RSA_KEY:-}" ]; then
        cmd="${cmd} -i ${ID_RSA_KEY}"
    fi

    echo ${cmd}
}

fn_parse_backup_flags() {
    cmd=""

    if [ -n "${SET_FLAGS:-}" ]; then
        cmd="${cmd} --rsync-set-flags \"${SET_FLAGS}\""
    elif [ -n "${APPEND_FLAGS:-}" ]; then
        cmd="${cmd} --rsync-append-flags \"${APPEND_FLAGS}\""
    fi
    if [ ! -z "${STRATEGY:-}" ]; then
        cmd="${cmd} --strategy ${STRATEGY}"
    fi
    echo ${cmd}
}

# create backup cli command
fn_create_backup_cmd () {

    cmd="rsync_tmbackup.sh $(fn_parse_ssh_flags) $(fn_parse_backup_flags) '${SOURCE}' '${TARGET}'"

    exclude_file_check=${EXCLUDE_FILE:-}

    if [ ! -z "${exclude_file_check}" ]; then
        cmd="${cmd} '${EXCLUDE_FILE}'"
    fi

    echo "$cmd"
}

# create restore cli command
fn_create_restore_cmd () {
    cmd="rsync -aP $(fn_parse_ssh_flags)"

    if [ "${WIPE_SOURCE_ON_RESTORE:-'false'}" = "true" ]; then
        cmd="${cmd} --delete"
    fi

    cmd="${cmd} '${TARGET}/latest/' '${SOURCE}/'"

    echo "$cmd"
}

fn_abort_if_crlf () {
    if ! awk '/\r$/ { exit(1) }' "$1"; then
        echo " [!] The profile has at least one Windows-style line ending"
        echo "     ERROR: failed to read the profile file: ${profile_file}" > /dev/stderr
        exit 1
    fi
}

# show help when invoked without parameters
if [ $# -eq 0 ]; then
    fn_display_usage
    exit 0
fi

action=${1?"param 1: action: backup, restore"}
profile=${2?"param 2: name of the profile"}

# load config
config_dir=${RTB_CONFIG_DIR:-"${HOME}/.rsync_tmbackup"}

# load profile
profile_dir="${config_dir}/conf.d"
profile_file="${profile_dir}/${profile}.inc"
exclude_file_convention="${profile_dir}/${profile}.excludes.lst"

if [ -r "$profile_file" ]; then
    # preset exclude file path before reading the profile
    if [ -r "$exclude_file_convention" ]; then
        EXCLUDE_FILE="$exclude_file_convention"
    fi

    # sanity check, crlf can break variable substitution
    fn_abort_if_crlf "$profile_file"
    # shellcheck disable=SC1090,SC1091
    . "$profile_file"
    # create cli command
    if [ "$action" = "restore" ]; then
        cmd=$(fn_create_restore_cmd)
    else
        cmd=$(fn_create_backup_cmd)
    fi
    if [ "${RTB_DEBUG:-'false'}" = "true" ]; then
        echo "# ${cmd}"
    else
        eval "$cmd"
    fi
else
    echo "Failed to read the profile file: ${profile_file}" > /dev/stderr
    exit 1
fi
