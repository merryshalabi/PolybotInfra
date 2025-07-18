output "control_plane_instance_id" {
  value = module.k8s_cluster.control_plane_instance_id
}

output "control_plane_public_ip" {
  value = module.k8s_cluster.control_plane_public_ip
}

output "worker_asg_name" {
  value = module.k8s_cluster.worker_asg_name
}
