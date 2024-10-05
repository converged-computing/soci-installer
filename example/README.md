# SOCI Installer

This is an example of the SOCI installer, which is a daemonset. This was tested on AWS since Google Cloud [supports streaming images](https://cloud.google.com/blog/products/containers-kubernetes/introducing-container-image-streaming-in-gke).

## Usage

Create a cluster. 

```bash
eksctl create cluster --config-file ./eks-config.yaml
```

If your credentials don't go through:

```bash
aws eks update-kubeconfig --region us-east-2 --name soci-installer-example
```

Deploy the daemonset, which will create one pod per node to install soci!

```bash
kubectl apply -f ../daemonset-installer.yaml
```

Create the pod, which will pull in about 4 seconds with soci.

```bash
kubectl apply -f pod.yaml
```
```bash
kubectl get pods
Events:
  Type    Reason     Age    From               Message
  ----    ------     ----   ----               -------
  Normal  Scheduled  3m32s  default-scheduler  Successfully assigned default/soci-sample-deployment-6fcdf78d68-9zrfn to ip-192-168-9-209.us-east-2.compute.internal
  Normal  Pulling    3m32s  kubelet            Pulling image "public.ecr.aws/soci-workshop-examples/tensorflow_gpu:latest"
  Normal  Pulled     3m27s  kubelet            Successfully pulled image "public.ecr.aws/soci-workshop-examples/tensorflow_gpu:latest" in 4.688039789s (4.688054981s including waiting)
  Normal  Created    3m27s  kubelet            Created container soci-container
  Normal  Started    3m27s  kubelet            Started container soci-container
```

When you are done:

```bash
eksctl delete cluster --config-file ./eks-config.yaml --wait
```

