
output "role_arn" {
  value = "${aws_iam_role.cluster-node.arn}"
}
output "configmap" {
  value = "${local.config_map_aws_auth}"
}
