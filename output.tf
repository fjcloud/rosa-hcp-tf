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
