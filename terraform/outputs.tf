output "web_private_key_ssm_name" {
  value       = aws_ssm_parameter.web_private_key.name
  description = "SSM parameter name for Web tier private key"
}

output "app_private_key_ssm_name" {
  value       = aws_ssm_parameter.app_private_key.name
  description = "SSM parameter name for App tier private key"
}

output "db_private_key_ssm_name" {
  value       = aws_ssm_parameter.db_private_key.name
  description = "SSM parameter name for DB tier private key"
}

output "web_public_ip" {
  value       = aws_instance.web_instance.public_ip
  description = "Public IP of the Web instance"
}

output "app_private_ip" {
  value       = aws_instance.app_instance.private_ip
  description = "Private IP of the App instance"
}

output "db_private_ip" {
  value       = aws_instance.db_instance.private_ip
  description = "Private IP of the DB instance"
}

output "vpn_psk_for_azure" {
  value       = "Projet_AWAZ10"
  description = "Pre-shared key to configure on Azure VPN Gateway"
}
