output "route-table-id" {
  value = "${aws_route_table.private-route.id}"
}

output "vpc-id" {
  value = "${aws_vpc.classv.id}"
}
