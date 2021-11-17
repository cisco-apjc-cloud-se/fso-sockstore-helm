## Bookinfo/AppD Variables ##
variable "appd_account_name" {
  type = string
}

variable "appd_account_key" {
  type = string
}

variable "bookinfo_chart_url" {
  type = string
}

variable "detailsService_replica_count" {
  type = number
}

variable "ratingsService_replica_count" {
  type = number
}

variable "reviewsService_replica_count" {
  type = number
}

variable "productPageService_replica_count" {
  type = number
}

## IWO Collector Variables ##
variable "iwo_cluster_name" {
  type = string
}

variable "iwo_chart_url" {
  type = string
}

variable "iwo_server_version" {
  type = string
}

variable "iwo_collector_image_version" {
  type = string
}
