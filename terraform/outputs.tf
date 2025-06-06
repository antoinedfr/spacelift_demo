# SSM Parameter names for each tier's SSH private key
output "web_private_key_ssm_name" {
  description = "SSM parameter name for Web tier private key"
  value       = aws_ssm_parameter.web_private_key.name
}

output "app_private_key_ssm_name" {
  description = "SSM parameter name for App tier private key"
  value       = aws_ssm_parameter.app_private_key.name
}

output "db_private_key_ssm_name" {
  description = "SSM parameter name for DB tier private key"
  value       = aws_ssm_parameter.db_private_key.name
}

# Public and private IPs for each EC2 instance
output "web_public_ip" {
  description = "Public IP of the Web (frontend) instance"
  value       = aws_instance.web_instance.public_ip
}

output "app_private_ip" {
  description = "Private IP of the App (backend) instance"
  value       = aws_instance.app_instance.private_ip
}

output "db_private_ip" {
  description = "Private IP of the DB instance"
  value       = aws_instance.db_instance.private_ip
}

# IPSec Pre-shared Key (PSK) for Azure VPN Gateway
output "vpn_psk_for_azure" {
  description = "Pre-shared key to configure in Azure VPN Gateway"
  value       = random_password.ipsec_psk.result
  sensitive   = true
}
