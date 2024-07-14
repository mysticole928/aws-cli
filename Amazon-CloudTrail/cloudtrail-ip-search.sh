#!/bin/bash

# Date: 2024-07-13

# This script queries a CloudTrail region for an IP
# address to check if an IAM User was accessing AWS services.
#
# The need/idea for the script came from an investigation 
# where an EC2 instance was configured without an 
# Instance Profile and connected IAM Role.
#
# It is possible to run processes on an EC2 instance using 
# IAM account credentials, the best practice is to use an 
# IAM Role attached to the instance.
#
# Without access to the EC2 instance, searching CloudTrail 
# for that EC2 Instance's IP address is one option.

# Choose date command: GNU or BSD
check_date_command() {
  if date --version >/dev/null 2>&1; then
    echo "gnu"
  else
    echo "bsd"
  fi
}

# Prompt for AWS region, default to AWS CLI configured region
default_region=$(aws configure get region)
read -p "Enter AWS region [default: $default_region]: " AWS_REGION
AWS_REGION=${AWS_REGION:-$default_region}

# Get the public IP address of the machine to use as the default
default_ip=$(curl -s http://checkip.amazonaws.com)
read -p "Enter IP address to filter [default: $default_ip]: " IP_ADDRESS
IP_ADDRESS=${IP_ADDRESS:-$default_ip}

# Prompt for date range, default to 7 days
read -p "Enter number of days to look back from today [default: 7]: " DAYS
DAYS=${DAYS:-7}

# BSD or GNU date command
date_cmd=$(check_date_command)

if [ "$date_cmd" = "gnu" ]; then
  START_DATE=$(date -u -d "-$DAYS days" +"%Y-%m-%dT%H:%M:%SZ")
elif [ "$date_cmd" = "bsd" ]; then
  START_DATE=$(date -u -v -"$DAYS"d +"%Y-%m-%dT%H:%M:%SZ")
else
  echo "Unsupported date command version"
  exit 1
fi

# The "cloudtrail lookup-event" command can cause throttling errors.
# According to the AWS documention, the rate of lookup requests
# is limited to two per second, per account, per region. 
#
# When this limit is exceeded, a throttling error occurs.
# 
# The documentation says that lookup-events is a paginated operation.
# Results can be received and processed in sections.  To get
# the next section use the parameter: NextToken


# Initialize variables
NEXT_TOKEN=""
MATCH_FOUND=false

# Function to process the CloudTrail events
process_events() {
  jq -r --arg ip_addr $IP_ADDRESS 'first(
    .Events[] |
    (.CloudTrailEvent |= fromjson) |
    select(.CloudTrailEvent.sourceIPAddress == $ip_addr and .CloudTrailEvent.userIdentity.type == "IAMUser") |
    {
      Username: .Username,
      User_Type: .CloudTrailEvent.userIdentity.type,
      SourceIPAddress: .CloudTrailEvent.sourceIPAddress,
      AccessKeyId: .CloudTrailEvent.userIdentity.accessKeyId,
      UserAgent: .CloudTrailEvent.userAgent
    }
  )'
}

# Loop to handle pagination
while [ "$MATCH_FOUND" = false ]; do
  if [ -z "$NEXT_TOKEN" ]; then
    response=$(aws cloudtrail lookup-events \
      --region $AWS_REGION \
      --start-time $START_DATE \
      --output json)
  else
    response=$(aws cloudtrail lookup-events \
      --region $AWS_REGION \
      --start-time $START_DATE \
      --next-token $NEXT_TOKEN \
      --output json)
  fi

  # Process the response and check for a match
  result=$(echo $response | process_events)
  
  if [ -n "$result" ]; then
    MATCH_FOUND=true
    break
  fi

  # Check if there's a next token for pagination
  NEXT_TOKEN=$(echo $response | jq -r '.NextToken // empty')
  if [ -z "$NEXT_TOKEN" ]; then
    break
  fi
done

# Format the output for better readability
if [ "$MATCH_FOUND" = true ]; then
  echo "Lookup Event Details:"
  echo "===================="
  echo "Username: $(echo $result | jq -r '.Username')"
  echo "User Type: $(echo $result | jq -r '.User_Type')"
  echo "Source IP Address: $(echo $result | jq -r '.SourceIPAddress')"
  echo "Access Key ID: $(echo $result | jq -r '.AccessKeyId')"
  echo "User Agent: $(echo $result | jq -r '.UserAgent')"
else
  echo "No matching events found."
fi