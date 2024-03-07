output "cluster_id" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.id
}

output "api_url" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.api_url
}

output "oidc_endpoint_url" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.sts.oidc_endpoint_url
}

output "console_url" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.console_url
}

output "rosa_admin_password_secret_name" {
  description = "Cluster admin password secret name"
  value       = aws_secretsmanager_secret.rosa_hcp.name
}
