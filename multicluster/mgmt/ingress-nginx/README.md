This NGINX Ingress Controller is a subproject of the Network SIG.

These manifests deploy the controller and configure a NodePort Service to expose it. A kind workload cluster can reach the kind management cluster through this Service. For a management cluster in a cloud, a LoadBalancer Service would provide external loadbalancing and a DNS record for easy service discovery.

For more information, see the [ingress-nginx documentation](https://kubernetes.github.io/ingress-nginx/).