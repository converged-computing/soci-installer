# SOCI Installer

The SOCI "Seekable OCI" Snapshotter is provided via [awslabs/soci-snapshotter](https://github.com/awslabs/soci-snapshotter) and is a containerd plugin that allows you to pull your containers (in layman's terms) "wicked fast." You can read more about the design and work done e.g.,:

> [Harter et al FAST '16](https://www.usenix.org/conference/fast16/technical-sessions/presentation/harter) found that image download accounts for 76% of container startup time, but on average only 6.4% of the fetched data is actually needed for the container to start doing useful work.

in the repository [README there](https://github.com/awslabs/soci-snapshotter). The author of this project noted that [image streaming was available on Google Cloud](https://cloud.google.com/kubernetes-engine/docs/how-to/image-streaming) but didn't seem to be on AWS. Thus, it provides a daemonset to install the service to nodes, and the other detail is that your registry needs to support the referrer's API to upload the associated artifacts with archive indexes.

## Usage

To install to your cluster, you should create it first! There is an [example](example) provided using eksctl. Then install the daemonset. 

```bash
kubectl apply -f ./daemonset-installer.yaml
```

The scripts are built into the container, so if you need to update or change something, just do it there. Note that you can change the version as the only argument to the entrypoint. This should coincide with a GitHub release (tag). Then you can create a pod with a big container:

```bash
kubectl apply -f example/pod.yaml
```

If you look at kubectl events, it will pull in ~4 seconds.

```console
19s                     Normal    Scheduled                 Pod/soci-sample-deployment-6fcdf78d68-9zrfn        Successfully assigned default/soci-sample-deployment-6fcdf78d68-9zrfn to ip-192-168-9-209.us-east-2.compute.internal
19s                     Normal    Pulling                   Pod/soci-sample-deployment-6fcdf78d68-9zrfn        Pulling image "public.ecr.aws/soci-workshop-examples/tensorflow_gpu:latest"
19s                     Normal    SuccessfulCreate          ReplicaSet/soci-sample-deployment-6fcdf78d68       Created pod: soci-sample-deployment-6fcdf78d68-9zrfn
19s                     Normal    ScalingReplicaSet         Deployment/soci-sample-deployment                  Scaled up replica set soci-sample-deployment-6fcdf78d68 to 1
14s                     Normal    Pulled                    Pod/soci-sample-deployment-6fcdf78d68-9zrfn        Successfully pulled image "public.ecr.aws/soci-workshop-examples/tensorflow_gpu:latest" in 4.688039789s (4.688054981s including waiting)
14s                     Normal    Created                   Pod/soci-sample-deployment-6fcdf78d68-9zrfn        Created container soci-container
14s                     Normal    Started                   Pod/soci-sample-deployment-6fcdf78d68-9zrfn        Started container soci-container
```

If we didn't use SOCI, it would take ~71 seconds.

```console
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  83s   default-scheduler  Successfully assigned default/soci-sample-deployment-6fcdf78d68-kjw62 to ip-192-168-0-107.us-east-2.compute.internal
  Normal  Pulling    82s   kubelet            Pulling image "public.ecr.aws/soci-workshop-examples/tensorflow_gpu:latest"
  Normal  Pulled     13s   kubelet            Successfully pulled image "public.ecr.aws/soci-workshop-examples/tensorflow_gpu:latest" in 1m9.208824967s (1m9.208841495s including waiting)
  Normal  Created    13s   kubelet            Created container soci-container
  Normal  Started    13s   kubelet            Started container soci-container
```

If you look at the logs of the daemonset, the first round will install soci and restart containerd. Since that will kill the nsenter pod, it goes in again, and then pulls the needed sandbox container. 

## Debugging

After `kubectl node-shell` into the node and `nsenter -t 1 -m bash` here are some [commands](https://github.com/awslabs/soci-snapshotter/blob/main/docs/debug.md) I use to see what is going on:

```console
# Is the snapshotter recognized by containerd?
sudo ctr plugin ls id==soci

# log
sudo journalctl -u soci-snapshotter.unit
```

## Previous Art 🎨

The repository provides a set of [setup instructions](https://github.com/awslabs/soci-snapshotter/blob/main/docs/eks.md) with a NodeConfig and a lot of manual steps, but I wanted the entire thing as a daemonset.

## Limitations

This does not currently support [registry authentication](https://github.com/awslabs/soci-snapshotter/blob/main/docs/kubernetes.md#registry-authentication-configuration) (meaning private images) but it could. It also is intended for AWS, because that's the cloud I have access to (that doesn't have a command line flag to enable it). Other clouds could be added, and the approach here improved upon. I made this quickly in the morning before a bike ride so it's not perfect.
