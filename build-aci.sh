#!/usr/bin/env bash
set -e

if [ "$#" -ne 3 ]; then
    echo "usage: build-aci.sh [input_journalbeat] [output_file.aci] [aci_name]"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "build-aci.sh: requires root privileges"
    exit 1
fi

INPUT_JB=${1}
OUTPUT_FILE=${2}
ACI_NAME=${3}

if [ ! -f "${INPUT_JB}" ]; then
    echo "journalbeat path is not a file: ${INPUT_JB}"
    exit 1
fi

JB_INSTALL_PATH="/opt/journalbeat/bin/journalbeat"

# A non-installed acbuild can be used, for example:
# ACBUILD=../../appc/acbuild/bin/acbuild
ACBUILD=${ACBUILD:-acbuild}

# Start the build with an empty ACI
${ACBUILD} --debug begin

# In the event of the script exiting, end the build
trap '{ export EXT=${?}; ${ACBUILD} --debug end && exit $EXT; }' EXIT

# Name the ACI
${ACBUILD} --debug set-name "${ACI_NAME}"

# Copy the app to the ACI
${ACBUILD} --debug copy "${INPUT_JB}" "${JB_INSTALL_PATH}"

chmod 0755 ".acbuild/currentaci/rootfs${JB_INSTALL_PATH}"
chown 0:0 ".acbuild/currentaci/rootfs${JB_INSTALL_PATH}"

# Execute journalbeat when the ACI is run
${ACBUILD} --debug set-exec -- "${JB_INSTALL_PATH}"

${ACBUILD} mount add "run-systemd" "/run/systemd"
${ACBUILD} mount add "lib64" "/lib64"
${ACBUILD} mount add "etc-journalbeat" "/etc/journalbeat"

# Write the result
${ACBUILD} --debug write --overwrite "${OUTPUT_FILE}"
