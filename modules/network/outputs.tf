output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Ordered [AZ-a, AZ-b]. EC2 goes in index 0."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Ordered [AZ-a, AZ-b]. Both feed the RDS subnet group."
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}