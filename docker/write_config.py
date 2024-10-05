#!/usr/bin/env python3

import toml
import os
import sys

containerd_config = os.path.join("/etc", "containerd", "config.toml")
if not os.path.exists(containerd_config):
    sys.exit(f"{containerd_config} does not exist.")

data = toml.load(containerd_config)
if "proxy_plugins" not in data:
    data["proxy_plugins"] = {}

# We need to get the sandbox image so we can re-pull with soci
sandbox_image = data['plugins']['io.containerd.grpc.v1.cri']['sandbox_image']
sandbox_registry = os.sep.join(sandbox_image.split(os.sep)[:-2])
aws_region = sandbox_registry.split('.')[-3]

def write_file(content, path):
    with open(path, 'w') as fd:
        fd.write(content)

# Write them to files we will know where to look...
write_file(sandbox_image, os.path.join("/opt", "aws", "sandbox-image.txt"))
write_file(sandbox_registry, os.path.join("/opt", "aws", "sandbox-registry.txt"))
write_file(aws_region, os.path.join("/opt", "aws", "aws-region.txt"))

# Make containerd aware of the SOCI plugin
data["proxy_plugins"]["soci"] = {
    # tell containerd that the SOCI plugin should implement snapshotter API
    "type": "snapshot",
    
    # tell containerd where to connect to the SOCI snapshotter 
    "address": "/run/soci-snapshotter-grpc/soci-snapshotter-grpc.sock",
}

# define the root data directory for the SOCI snapshotter
# Helps:
#  calculate disk utilization
#  enforce storage limits
#  trigger garbage collection.

data["proxy_plugins"]["soci"]["exports"] = {"root": "/var/lib/soci-snapshotter-grpc"}

# This series of keys should already be there
# But just be extra safe and check anyway
if "io.containerd.grpc.v1.cri" not in data["plugins"]:
    data['plugins']["io.containerd.grpc.v1.cri"] = {}
if "containerd" not in data['plugins']["io.containerd.grpc.v1.cri"]:
    data['plugins']["io.containerd.grpc.v1.cri"]["containerd"] = {}

# Tell containerd to use SOCI by default. must match the proxy_plugin name.
data["plugins"]["io.containerd.grpc.v1.cri"]["containerd"]["snapshotter"] = "soci"

# Tell containerd to send lazy loading information to the SOCI snapshotter
data["plugins"]["io.containerd.grpc.v1.cri"]["containerd"][
    "disable_snapshot_annotations"
] = False

# Show the user in the log for debugging
print(toml.dumps(data))

# Write back to file
write_file(toml.dumps(data), containerd_config)
