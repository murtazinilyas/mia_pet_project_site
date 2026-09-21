resource "yandex_container_registry_iam_binding" "puller" { # Даем права всем на скачивание образа приложения из нашего Yandex Container Registry
  registry_id = local.registry_id
  role        = "container-registry.images.puller"

  members = [
    "system:allUsers",
  ]
}