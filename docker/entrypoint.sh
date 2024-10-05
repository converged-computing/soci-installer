#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

set -x

SOCI_VERSION=${1:-"0.7.0"}
INSTALL_FILE="/soci-install/install-soci.sh"

if [[ ! -f "$INSTALL_FILE" ]]; then
    echo "Expected to find install file '$INSTALL_FILE', but it does not exist"
    exit 1
fi

# We need to copy everything into mount from container 
echo "Copying install files onto the host node"
cp ${INSTALL_FILE} /mnt/install/install.sh
chmod +x /mnt/install/install.sh
cp /soci-install/write_config.py /mnt/install/write_config.py
cp /soci-install/config.toml /mnt/install/config.toml

# This gets executed with nsenter to pid 1, the init process
echo "Executing nsenter to connect from container to host"
nsenter -t 1 -m bash /mnt/install/install.sh "${SOCI_VERSION}"
RESULT="${PIPESTATUS[0]}"

if [ $RESULT -eq 0 ]; then
    echo "Completed successfully - soci is setup"
    sleep infinity
else
    echo "Failed during nsenter install"
    exit 1
fi
