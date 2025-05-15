output "website_url" {
  description = "The URL for the main website"
  value       = "https://${aws_cloudfront_distribution.website_distribution.domain_name}"
}

output "assets_url" {
  description = "The URL for the application assets"
  value       = "https://${aws_cloudfront_distribution.assets_distribution.domain_name}"
}

output "faucet_url" {
  description = "The URL for the faucet application"
  value       = "https://${aws_cloudfront_distribution.faucet_distribution.domain_name}"
}

output "blockchain_explorer_url" {
  description = "The URL for the blockchain explorer"
  value       = "https://${aws_cloudfront_distribution.blockchain_explorer_distribution.domain_name}"
}

output "all_urls" {
  description = "Map of all application URLs"
  value = {
    website    = "https://${aws_cloudfront_distribution.website_distribution.domain_name}"
    assets     = "https://${aws_cloudfront_distribution.assets_distribution.domain_name}"
    faucet     = "https://${aws_cloudfront_distribution.faucet_distribution.domain_name}"
    explorer   = "https://${aws_cloudfront_distribution.blockchain_explorer_distribution.domain_name}"
  }
}