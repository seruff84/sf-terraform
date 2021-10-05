terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.61.0"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = "b1giech89svtpr2sgq4c"
  folder_id = "b1gkk6na84ph4jq1hi38"
  zone      = "ru-central1-a"
}

