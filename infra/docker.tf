resource "docker_compose" "project-app" { # Запускаем приложение с помощью remote docker context
  project_name = "${var.env_name}-app"
  wait         = true
  wait_timeout = "30s"
  config_paths = [
    "${var.path_to_app}/compose.yaml",
  ]
  depends_on = [module.project_vms]
}