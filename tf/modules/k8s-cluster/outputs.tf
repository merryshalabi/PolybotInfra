output "control_plane_instance_id" {
  description = "ID of the control plane EC2 instance"
  value       = aws_instance.control_plane.id
}

output "control_plane_public_ip" {
  description = "Public IP address of the control plane EC2"
  value       = aws_instance.control_plane.public_ip
}

output "worker_asg_name" {
  description = "Name of the Auto Scaling Group for worker nodes"
  value       = aws_autoscaling_group.worker_asg.name
}
