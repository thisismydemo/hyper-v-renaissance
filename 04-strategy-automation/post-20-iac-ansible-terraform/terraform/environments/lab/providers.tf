provider "hyperv" {
  user            = var.hyperv_user
  password        = var.hyperv_password
  host            = var.hyperv_host
  port            = var.hyperv_port
  https           = var.hyperv_use_https
  insecure        = var.hyperv_insecure
  use_ntlm        = var.hyperv_use_ntlm
  tls_server_name = var.hyperv_tls_server_name
  cacert_path     = var.hyperv_cacert_path
  cert_path       = var.hyperv_cert_path
  key_path        = var.hyperv_key_path
  script_path     = "C:/Windows/Temp/terraform_%RAND%.cmd"
  timeout         = "60s"
}
