resource "yandex_dns_zone" "pc-master-bgm" {
  name      = "pc-master-bgm"
  public    = true
  zone      = "pc-master-bgm.ru."
}

resource "yandex_dns_recordset" "main" {
  data = [
    module.project_vms.external_ip_address[0]
  ]
  name    = "@.pc-master-bgm.ru."
  ttl     = 600
  type    = "A"
  zone_id = yandex_dns_zone.pc-master-bgm.id
}