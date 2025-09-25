output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}

output "table_name" {
  value = aws_dynamodb_table.demo.name
}

output "lambda_name" {
  value = aws_lambda_function.handler.function_name
}
