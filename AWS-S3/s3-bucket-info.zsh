#!/usr/bin/env zsh
set -euo pipefail

# Version 1.0
# Created: 2026-01-02
# Outputs common S3 bucket configuration in YAML.
# Requires: aws cli v2, yq (mikefarah yq v4)
# Usage:
#   s3-bucket-info.zsh <bucket-name>
#
# Description:
#   Outputs configuration and metadata for an Amazon S3 bucket in YAML format.
#   For each supported S3 "get-bucket-*" API, the script:
#     - Prints the configuration if it exists
#     - Prints "status: not configured" when the configuration is absent
#     - Prints an error block for unexpected failures
#
#   The bucket creation date is retrieved using `s3api list-buckets`.
#   This the only authoritative source for S3 bucket creation time.
#
# Output:
#   YAML-formatted sections include:
#     - Caller identity
#     - Bucket creation date
#     - Location, versioning, encryption
#     - Public access block, policy, logging
#     - Tags, lifecycle configuration
#     - ACL, ownership controls, CORS, and replication
#
# Requirements:
#   - zsh
#   - aws CLI v2
#   - yq (mikefarah/yq v4)
#
# Notes:
#   - S3 buckets are global; the script does not rely on --region for creation date
#   - Some configurations may not exist for a given bucket; this is normal/expected
#   - Intended for auditing, troubleshooting, and documentation
#
# Example:
#   ./s3-bucket-info.zsh <s3-bucket-name>
#

if (( $# != 1 )); then
  print -u2 "Usage: $0 <bucket-name>"
  exit 2
fi

bucket="$1"

# Print a YAML section header

section() {
  print "----"
  print "$1:"
}

# Indent stdin by 2 spaces (for nested YAML under a key)

indent2() {
  sed 's/^/  /'
}

# Decide whether an aws s3api error means "not configured"
# Uses heredoc with grep -f

is_not_configured_err() {
  grep -qEf /dev/stdin <<'EOF'
NoSuchBucket
NoSuchTagSet
NoSuchLifecycleConfiguration
NoSuchPublicAccessBlockConfiguration
NoSuchBucketPolicy
NoSuchBucketLoggingStatus
NoSuchReplicationConfiguration
NoSuchEncryptionConfiguration
NoSuchWebsiteConfiguration
NoSuchCORSConfiguration
NoSuchOwnershipControls
NoSuchAccelerateConfiguration
NoSuchRequestPaymentConfiguration
ServerSideEncryptionConfigurationNotFoundError
NotFound
404
EOF
}

# Run an AWS CLI command that returns JSON; convert to YAML if successful.
# If it fails because config doesn't exist, print "status: not configured".
# Otherwise print an "error" block with the captured message.

json_info_or_not_configured() {
  local title="$1"
  shift

  local out rc
  out="$("$@" 2>&1)" || rc=$?
  rc=${rc:-0}

  section "$title"
  if (( rc == 0 )); then
    print -r -- "$out" | yq -p=json -o=yaml '.' | indent2
  else
    if print -r -- "$out" | is_not_configured_err; then
      print "  status: not configured"
    else
      print "  status: error"
      print "  message: |"
      print -r -- "$out" | sed 's/^/    /'
    fi
  fi
}

# Header info

section "Bucket"
print "  name: ${bucket}"

section "CallerIdentity"
aws sts get-caller-identity --output json | yq -p=json -o=yaml '.' | indent2

# Bucket "creation date" only comes from list-buckets

section "Creation"
aws s3api list-buckets \
  --query "Buckets[?Name==\`${bucket}\`]|[0].{Name:Name,CreationDate:CreationDate}" \
  --output json \
| yq -p=json -o=yaml '.' | indent2

# Core config from your list (and a few common extras)

json_info_or_not_configured "Location"           aws s3api get-bucket-location                 --bucket "$bucket" --output json
json_info_or_not_configured "Versioning"         aws s3api get-bucket-versioning               --bucket "$bucket" --output json
json_info_or_not_configured "Encryption"         aws s3api get-bucket-encryption               --bucket "$bucket" --output json
json_info_or_not_configured "PublicAccessBlock"  aws s3api get-public-access-block             --bucket "$bucket" --output json
json_info_or_not_configured "Policy"             aws s3api get-bucket-policy                   --bucket "$bucket" --output json
json_info_or_not_configured "Logging"            aws s3api get-bucket-logging                  --bucket "$bucket" --output json
json_info_or_not_configured "Tagging"            aws s3api get-bucket-tagging                  --bucket "$bucket" --output json
json_info_or_not_configured "Lifecycle"          aws s3api get-bucket-lifecycle-configuration  --bucket "$bucket" --output json

# Useful extras

json_info_or_not_configured "ACL"                aws s3api get-bucket-acl                      --bucket "$bucket" --output json
json_info_or_not_configured "PolicyStatus"       aws s3api get-bucket-policy-status            --bucket "$bucket" --output json
json_info_or_not_configured "OwnershipControls"  aws s3api get-bucket-ownership-controls       --bucket "$bucket" --output json
json_info_or_not_configured "CORS"               aws s3api get-bucket-cors                     --bucket "$bucket" --output json
json_info_or_not_configured "Website"            aws s3api get-bucket-website                  --bucket "$bucket" --output json
json_info_or_not_configured "Replication"        aws s3api get-bucket-replication              --bucket "$bucket" --output json
json_info_or_not_configured "Accelerate"         aws s3api get-bucket-accelerate-configuration --bucket "$bucket" --output json
json_info_or_not_configured "RequestPayment"     aws s3api get-bucket-request-payment          --bucket "$bucket" --output json
json_info_or_not_configured "ObjectLock"         aws s3api get-object-lock-configuration       --bucket "$bucket" --output json
