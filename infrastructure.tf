variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region = "${var.region}"
}

////
// general setup
//

// the bucket must be configured with the -backend-config flag on `terraform init`
terraform {
  backend "s3" {
    key = "logs/terraform.tfstate"
    region = "us-east-1"
  }
}

////
// CloudTrail
//

variable "account_id" {}
variable "cloudtrail_s3_bucket" {}
variable "cloudtrail_log_group_name" {}
variable "cloudtrail_name" {}

resource "aws_cloudtrail" "audit" {
  name                       = "${var.cloudtrail_name}"
  s3_bucket_name             = "${var.cloudtrail_s3_bucket}"
  cloud_watch_logs_role_arn  = "${aws_iam_role.cloudtrail.arn}"
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}"
  enable_log_file_validation = true
  is_multi_region_trail      = true
}

resource "aws_iam_role" "cloudtrail" {
  name               = "logging-aws-cloudtrail"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cloudtrail" {
  name   = "cloudtrail-policy"
  role   = "logging-aws-cloudtrail"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {

      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream"
      ],
      "Resource": [
        "arn:aws:logs:${var.region}:${var.account_id}:log-group:${aws_cloudwatch_log_group.cloudtrail.name}:log-stream:${var.account_id}_CloudTrail_${var.region}*"
      ]

    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:${var.region}:${var.account_id}:log-group:${aws_cloudwatch_log_group.cloudtrail.name}:log-stream:${var.account_id}_CloudTrail_${var.region}*"
      ]
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name = "${var.cloudtrail_log_group_name}"
}


////
// ElasticSearch
//

variable "es_domain_name" {}
variable "travis_user" {}
variable "es_email_principals" {
  type = "list"
}

resource "aws_elasticsearch_domain" "es" {
  domain_name = "${var.es_domain_name}"
  elasticsearch_version = "5.5"

  cluster_config {
    instance_type = "m3.xlarge.elasticsearch"
    instance_count = 2
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp2"
    volume_size = 512
  }

  access_policies = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          ${join(", ", formatlist("\"arn:aws:sts::%s:assumed-role/dss-elk-oidc-proxy/%s\"", var.account_id, var.es_email_principals))},
          "arn:aws:iam::${var.account_id}:user/${var.travis_user}"
        ]
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:${var.region}:${var.account_id}:domain/${var.es_domain_name}/*"
    }
  ]
}
EOF
}


////
// Alerts
//

resource "aws_cloudformation_stack" "alerts" {
  name = "CloudTrail-Monitoring"
  template_body = "${file("config/cloudformation/CloudWatch_Alarms_for_CloudTrail_API_Activity.json")}"
}


////
// GCP to CloudWatch Logs exporter
//

resource "aws_iam_role" "gcp_to_cwl" {
  name               = "gcp-to-cwl-exporter-staging"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "gcp_to_cwl" {
  name   = "gcp-to-cwl-exporter-staging"
  role   = "gcp-to-cwl-exporter-staging"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "*"
        }
    ]
}
EOF
}
