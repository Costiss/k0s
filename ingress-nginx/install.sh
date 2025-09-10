#helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
#helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.hostNetwork=true \
  --set controller.allowSnippetAnnotations=true
