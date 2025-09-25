output "audit_bucket_name" {
  value = aws_s3_bucket.audit_logs.bucket
}

output "kms_logs_key_arn" {
  value = aws_kms_key.logs.arn
}

output "org_trail_arn" {
  value = try(aws_cloudtrail.org.arn, null)
}
