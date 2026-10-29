
output "public_ip" {
  description = "Public IP address of the portfolio server"
  value       = aws_instance.portfolio.public_ip
}

output "website_url" {
  description = "Portfolio website URL"
  value       = "http://${aws_instance.portfolio.public_ip}"
}
