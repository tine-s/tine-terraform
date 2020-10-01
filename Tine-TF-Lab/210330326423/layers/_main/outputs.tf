output "remote_state_configuration_example" {
  description = "A suggested terraform block to put into the build layers"

  value = <<EOF


  terraform {
    required_version = ">= 0.12"

    backend "s3" {
      # this key must be unique for each layer!
      bucket  = "${aws_s3_bucket.state.id}"
      key     = "terraform.EXAMPLE.000base.tfstate"
      region  = "${aws_s3_bucket.state.region}"
      encrypt = "true"
    }
  }
EOF

}

output "state_bucket_id" {
  description = "The ID of the bucket to be used for state files."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_region" {
  description = "The region the state bucket resides in."
  value       = aws_s3_bucket.state.region
}

output "state_import_example" {
  description = "An example to use this layers state in another."

  value = <<EOF


  data "terraform_remote_state" "main_state" {
    backend = "local"

    config = {
      path = "../../_main/terraform.tfstate"
    }
  }
EOF
}
