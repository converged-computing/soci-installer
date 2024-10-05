#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

set -x

# Version of the snapshotter to install
VERSION=${1:-"0.7.0"}

# Did we already install here?
if [[ -f "/etc/soci-snapshotter-grpc/install-complete.txt" ]];
  then
    echo "SOCI snapshotter was already installed"
    ctr plugin ls id==soci

    # Use nerdctl to re-pull the missing pause container
    # This needs to happen after the restart!
    sandbox_image=$(cat /opt/aws/sandbox-image.txt)
    sudo /usr/local/bin/nerdctl pull --snapshotter soci ${sandbox_image}
    sleep infinity
fi

# containerd should already be installed.
# the credential helper is needed for nerdctl login
yum install -y amazon-ecr-credential-helper
yum install fuse -y || apt-get install -y fuse
python3 -m pip install toml

# Install x86 or arm
if [[ "$(uname -m)" == "x86_64" ]]; then
  wget https://github.com/awslabs/soci-snapshotter/releases/download/v${VERSION}/soci-snapshotter-${VERSION}-linux-amd64.tar.gz
  tar -xzvf soci-snapshotter-${VERSION}-linux-amd64.tar.gz
else
  wget https://github.com/awslabs/soci-snapshotter/releases/download/v${VERSION}/soci-snapshotter-${VERSION}-linux-arm64.tar.gz
fi

# Move into bin - the service file expects in /usr/local/bin
chmod +x ./soci ./soci-snapshotter-grpc
mv ./soci /usr/local/bin/soci
mv /soci-snapshotter-grpc /usr/local/bin/soci-snapshotter-grpc
/usr/local/bin/soci-snapshotter-grpc --version

# The AWS nodes seem to use systemd
wget https://raw.githubusercontent.com/awslabs/soci-snapshotter/refs/heads/main/soci-snapshotter.service
mv soci-snapshotter.service /usr/lib/systemd/system/soci-snapshotter.service
sudo systemctl daemon-reload

sudo systemctl enable --now soci-snapshotter
sudo systemctl status soci-snapshotter

# https://github.com/awslabs/soci-snapshotter/blob/main/docs/kubernetes.md#containerd-configuration

# This also will write the pause container and the registry to login to for the pause container
# without the pause container it won't work to pull images when we restart.
# This is what I figured out to get it working.
python3 /mnt/install/write_config.py

# Note that this is very AWS specific, but this can be extended to other kubernetes setups
# You just need to login to the registry with the pause container, and pull with nerdctl using
# the soci snapshotter
sandbox_image=$(cat /opt/aws/sandbox-image.txt)
sandbox_registry=$(cat /opt/aws/sandbox-registry.txt)
aws_region=$(cat /opt/aws/aws-region.txt)

# Ensure sandbox image is available to calling container
echo $sandbox_image >> /mnt/install/sandbox-image.txt

aws ecr get-login-password --region ${aws_region} | nerdctl login --username AWS --password-stdin ${sandbox_registry}
aws ecr get-login-password --region ${aws_region} | sudo /usr/local/bin/nerdctl login --username AWS --password-stdin ${sandbox_registry}

tail /etc/containerd/config.toml
echo "Restarting containerd - this will end the daemonset"

# Cache CRI credentials
mkdir -p /etc/soci-snapshotter-grpc
cp /mnt/install/config.toml /etc/soci-snapshotter-grpc/config.toml

# This will kick you out - the node will restart
touch /etc/soci-snapshotter-grpc/install-complete.txt
systemctl restart containerd && sudo /usr/local/bin/nerdctl pull --snapshotter soci ${sandbox_image}

# sudo systemctl stop containerd
