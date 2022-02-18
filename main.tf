terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "mel-ciscolabs-com"
    workspaces {
      name = "fso-teastore-helm"
    }
  }
  required_providers {
    // intersight = {
    //   source = "CiscoDevNet/intersight"
    //   # version = "1.0.12"
    // }
    helm = {
      source = "hashicorp/helm"
      # version = "2.0.2"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

### Remote State - Import Kube Config ###
data "terraform_remote_state" "iks" {
  backend = "remote"

  config = {
    organization = "mel-ciscolabs-com"
    workspaces = {
      name = "fso-teastore-iks"
    }
  }
}

### Decode Kube Config ###
locals {
  kube_config = yamldecode(base64decode(data.terraform_remote_state.iks.outputs.kube_config))
}


### Providers ###
provider "kubernetes" {
  # alias = "iks-k8s"

  host                   = local.kube_config.clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
  client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
  client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
}

provider "helm" {
  kubernetes {
    host                   = local.kube_config.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
  }
}

### Kubernetes  ###

### Add Namespaces ###

resource "kubernetes_namespace" "sca" {
  metadata {
    annotations = {
      name = "sca"
    }
    labels = {
      # app = "sca"
      "app.kubernetes.io/name" = "sca"
    }
    name = "sca"
  }
}

resource "kubernetes_namespace" "iwo-collector" {
  metadata {
    annotations = {
      name = "iwo-collector"
    }
    labels = {
      # app = "iwo"
      "app.kubernetes.io/name" = "iwo"
    }
    name = "iwo-collector"
  }
}

resource "kubernetes_namespace" "teastore" {
  metadata {
    annotations = {
      name = "teastore"
    }
    labels = {
      "app.kubernetes.io/name" = "teastore"
      "app.kubernetes.io/version" = "0.3.0"

      ## SMM Sidecard Proxy Auto Injection ##
      "istio.io/rev" = "cp-v111x.istio-system"

    }
    name = "teastore"
  }
}

resource "kubernetes_namespace" "appd" {
  metadata {
    annotations = {
      name = "appdynamics"
    }
    labels = {
      # app = "appdynamics"
      "app.kubernetes.io/name" = "appdynamics"
    }
    name = "appdynamics"
  }
}

### Helm ###

## Add Secure Cloud Analytics - K8S Agent Release ##
resource "helm_release" "sca" {
 namespace   = kubernetes_namespace.sca.metadata[0].name
 name        = "sca"

 chart       = var.sca_chart_url

 set {
   name  = "sca.service_key"
   value = var.sca_service_key
 }
}

## Add IWO K8S Collector Release ##
resource "helm_release" "iwo-collector" {
 namespace   = kubernetes_namespace.iwo-collector.metadata[0].name
 name        = "iwo-collector"

 chart       = var.iwo_chart_url

 set {
   name  = "iwoServerVersion"
   value = var.iwo_server_version
 }

 set {
   name  = "collectorImage.tag"
   value = var.iwo_collector_image_version
 }

 set {
   name  = "targetName"
   value = var.iwo_cluster_name
 }
}

## Add Tea Store Release  ##
resource "helm_release" "teastore" {
 namespace   = kubernetes_namespace.teastore.metadata[0].name
 name        = "teastore"

 chart       = var.teastore_chart_url

 values = [<<EOF
teastore_auth:
 replicas: 1
 resources:
   memory: "256M"
   cpu: "800m"
 service:
   type: ClusterIP # ClusterIP, NodePort, LoadBalancer
   targetPort: 8080
   port: 8080 ## External Port for LoadBalancer/NodePort
teastore_db:
 replicas: 1
 resources:
   memory: "256M"
   cpu: "800m"
 service:
   type: ClusterIP # ClusterIP, NodePort, LoadBalancer
   targetPort: 3306
   port: 3306 ## External Port for LoadBalancer/NodePort
teastore_image:
  replicas: 1
  resources:
    memory: "256M"
    cpu: "800m"
  service:
    type: ClusterIP # ClusterIP, NodePort, LoadBalancer
    targetPort: 8080
    port: 8080 ## External Port for LoadBalancer/NodePort
teastore_loadgen:
  replicas: 1
  resources:
    memory: "256M"
    cpu: "800m"
  settings:
    num_users: 10
    ramp_up: 1
teastore_loadgen_amex:
  replicas: 1
  resources:
    memory: "256M"
    cpu: "800m"
  settings:
    num_users: 10
    ramp_up: 1
teastore_persistence:
  replicas: 1
  resources:
    memory: "256M"
    cpu: "800m"
  service:
    type: ClusterIP # ClusterIP, NodePort, LoadBalancer
    targetPort: 8080
    port: 8080 ## External Port for LoadBalancer/NodePort
teastore_recommender:
  replicas: 1
  resources:
    memory: "256M"
    cpu: "800m"
  service:
    type: ClusterIP # ClusterIP, NodePort, LoadBalancer
    targetPort: 8080
    port: 8080 ## External Port for LoadBalancer/NodePort
teastore_registry:
  replicas: 1
  resources:
    memory: "256M"
    cpu: "800m"
  service:
    type: ClusterIP # ClusterIP, NodePort, LoadBalancer
    targetPort: 8080
    port: 8080 ## External Port for LoadBalancer/NodePort
teastore_webui:
  replicas: 2
  resources:
    memory: "256M"
    cpu: "800m"
  service:
    type: LoadBalancer # ClusterIP, NodePort, LoadBalancer
    targetPort: 8080
    port: 8080 ## External Port for LoadBalancer/NodePort
  env:
    visa_url: "https://fso-payment-gw-sim.azurewebsites.net/api/payment"
    mastercard_url: "https://fso-payment-gw-sim.azurewebsites.net/api/payment"
    amex_url: "https://amex-fso-payment-gw-sim.azurewebsites.net/api/payment"
EOF
]

 depends_on = [helm_release.appd-cluster-agent]
}

## Add Metrics Server Release ##
# - Required for AppD Cluster Agent

resource "helm_release" "metrics-server" {
  name = "metrics-server"
  namespace = "kube-system"
  repository = "https://charts.bitnami.com/bitnami"
  chart = "metrics-server"

  set {
    name = "apiService.create"
    value = true
  }

  set {
    name = "extraArgs.kubelet-insecure-tls"
    value = true
  }

  set {
    name = "extraArgs.kubelet-preferred-address-types"
    value = "InternalIP"
  }

}

## Add Appd Cluster Agent Release  ##
resource "helm_release" "appd-cluster-agent" {
 namespace   = kubernetes_namespace.appd.metadata[0].name
 name        = "fso-teastore-cluster-agent"

 repository  = "https://ciscodevnet.github.io/appdynamics-charts"
 chart       = "cluster-agent"

 set {
   name = "controllerInfo.url"
   value = format("https://%s.saas.appdynamics.com:443", var.appd_account_name)
 }

 set {
   name = "controllerInfo.account"
   value = var.appd_account_name
 }

 set {
   name = "controllerInfo.accessKey"
   value = var.appd_account_key
 }

 set {
   name = "controllerInfo.username"
   value = var.appd_account_username
 }

 set {
   name = "controllerInfo.password"
   value = var.appd_account_password
 }

 ## Monitor All Namespaces
 set {
   name = "clusterAgent.nsToMonitorRegex"
   value = ".*"
 }

 ## Auto Instrumentation

 // set {
 //   name = "instrumentationConfig.enabled"
 //   value = true
 // }

 // - language: java

# auto-instrumentation config
 values = [<<EOF
 instrumentationConfig:
   enabled: true
   instrumentationMethod: env
   nsToInstrumentRegex: teastore
   defaultAppName: TeaStore-RW
   appNameStrategy: manual
   instrumentationRules:
     - namespaceRegex: teastore
       language: java
       labelMatch:
         - framework: java
       imageInfo:
         image: docker.io/appdynamics/java-agent:latest
         agentMountPath: /opt/appdynamics
         imagePullPolicy: Always
EOF
]

// ## Auto Instrumentation
// values = [<<EOF
// instrumentationMethod: Env
// nsToInstrumentRegex: teastore
// defaultAppName: teastore-richwats
// instrumentationRules:
//   - language: java
//     imageInfo:
//       image: docker.io/appdynamics/java-agent:latest
//       agentMountPath: /opt/appdynamics
// EOF
// ]

// instrumentationConfig:
//   enabled: true
//   instrumentationMethod: Env
//   nsToInstrumentRegex: teastore
//   defaultAppName: teastore
//   appNameStrategy: namespace
//   imageInfo:
//     java:
//       image: "docker.io/appdynamics/java-agent:latest"
//       agentMountPath: /opt/appdynamics
//       imagePullPolicy: Always
//   instrumentationRules:
//     - namespaceRegex: groceries
//       language: dotnetcore
//       imageInfo:
//         image: "docker.io/appdynamics/dotnet-core-agent:latest"
//         agentMountPath: /opt/appdynamics
//         imagePullPolicy: Always
//     - namespaceRegex: books
//       matchString: openmct
//       language: nodejs
//       imageInfo:
//         image: "docker.io/appdynamics/nodejs-agent:20.5.0-alpinev10"
//         agentMountPath: /opt/appdynamics
//         imagePullPolicy: Always
//       analyticsHost: <hostname of the Analytics Agent>
//       analyticsPort: 443
//       analyticsSslEnabled: true

 depends_on = [helm_release.metrics-server]
}

## Add Appd Machine Agent Release  ##
resource "helm_release" "appd-machine-agent" {
 namespace   = kubernetes_namespace.appd.metadata[0].name
 name        = "fso-teastore-machine-agent"

 repository  = "https://ciscodevnet.github.io/appdynamics-charts"
 chart       = "machine-agent"

 // helm install --namespace=appdynamics \
 // --set .accessKey=<controller-key> \
 // --set .host=<*.saas.appdynamics.com> \
 // --set controller.port=443 --set controller.ssl=true \
 // --set controller.accountName=<account-name> \
 // --set controller.globalAccountName=<global-account-name> \
 // --set analytics.eventEndpoint=https://analytics.api.appdynamics.com \
 // --set agent.netviz=true serverviz appdynamics-charts/machine-agent

 set {
   name = "controller.accessKey"
   value = var.appd_account_key
 }

 set {
   name = "controller.host"
   value = format("%s.saas.appdynamics.com", var.appd_account_name)
 }

 set {
   name = "controller.port"
   value = 443
 }

 set {
   name = "controller.ssl"
   value = true
 }

 set {
   name = "controller.accountName"
   value = var.appd_account_name
 }

 set {
   name = "controller.globalAccountName"
   value = var.appd_account_name
 }

 set {
   name = "analytics.eventEndpoint"
   value = "https://analytics.api.appdynamics.com"
 }

 set {
   name = "agent.netviz"
   value = true
 }

 set {
   name = "openshift.scc"
   value = false
 }

 depends_on = [helm_release.metrics-server]
}

# Prometheus included as part of SMM..

# ## Add Prometheus (Kube-state-metrics, node-exporter, alertmanager)  ##
# resource "helm_release" "prometheus" {
#   namespace   = "kube-system"
#   name        = "prometheus"
#
#   repository  = "https://prometheus-community.github.io/helm-charts"
#   chart       = "prometheus"
#
#   ## Delay Chart Deployment
#   depends_on = [helm_release.metrics-server]
# }
