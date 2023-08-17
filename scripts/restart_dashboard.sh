export KUBECONFIG=configs/config
kubectl rollout restart deployment/kubernetes-dashboard --namespace=kubernetes-dashboard