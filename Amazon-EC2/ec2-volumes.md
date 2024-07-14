# EC2 Volume Infomation Snippets

## Create Shell Variables

```shell
export INSTANCE_ID="<-INSTANCE-ID->"
export AWS_REGION="<--AWS-REGION-->"
```

## Get EC2 Volume ID(s)

```shell
aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $INSTANCE_ID \
  --query "Reservations[*].Instances[*].BlockDeviceMappings[*].Ebs.VolumeId" \
  --output yaml
```

## Check encryption status on EC2 Volume(s)

```shell
    aws ec2 describe-volumes \
    --region #AWS_REGION \
    --volume-ids $VOLUME_ID
    --query "Volumes[*].
        {VolumeId:VolumeId,
        Encrypted:Encrypted}" \
    --output yaml
```

## Shell script to display information for multiple volumes

```shell
#!/bin/bash

# Get the volume IDs attached to the instance

VOLUME_IDS=$(aws ec2 describe-instances \
                --region $AWS_REGION \
                --instance-ids $INSTANCE_ID \
                --query "Reservations[*].Instances[*].BlockDeviceMappings[*].Ebs.VolumeId"
                --output text )

# Loop through volume IDS to check encryption status

for VOLUME_ID in $VOLUME_IDS; do
    ENCRYPTION_STATUS=$(aws ec2 describe-volumes \
                    --region $AWS_REGION \
                    --volume-ids $VOLUME_ID \
                    --query "Volumes[*].{VolumeId:VolumeId,Encrypted:Encrypted}" \
                    --output text )
    echo "$ENCRYPTION_STATUS"
done
```

## EC2 EBS Mappings that checks traditional and NVME drives

```shell
aws ec2 describe-instances \
    --region $AWS_REGION \
    --instance-ids $INSTANCE_ID \
    --query "Reservations[*].Instances[*].
        BlockDeviceMappings[?DeviceName==\`/dev/xvda\` || DeviceName==\`/dev/sda1\`].
        Ebs.VolumeId" \
    --output yaml
```

> [!note]
> The backticks are necessary in the `--query` parameter. They escape
> string literals for use by JMESPath and ensure the accurate filtering
> and extraction of data from the JSON.

## Get Detailed Information about Volumes Attached to an EC2 Instances

```shell
aws ec2 describe-volumes \
    --region $AWS_REGION \
    --filters Name=attachment.instance-id,Values=$INSTANCE_ID \
    --query "Volumes[*].{
        EBS_VolumeId:VolumeId,
        EBS_Volume:VolumeType,
        Encrypted:Encrypted,
        KMS_Key_ID:KmsKeyId,
        Volume_Attachments:Attachments
        }" \
    --output yaml
```

## Get Instsance Profile Information from an EC2 Instance

Note: When $INSTANCE_ID is null, all Instances are returned.
(Provided the user has permission to see them.)

```shell
aws ec2 describe-instances \
    --region $AWS_REGION \
    --instance-ids $INSTANCE_ID \
    --query "Reservations[*].Instances[*].
        IamInstanceProfile" \
    --output yaml
```

## Get KMS Encryption Key ID from an EBS Volume

```shell
aws ec2 describe-volumes \
    --region $AWS_REGION \
    --filters Name=attachment.instance-id,Values=$INSTANCE_ID \
    --query "Volumes[*].{
        EBS_VolumeId:VolumeId,
        KMS_Key_ID:KmsKeyId
        }" \
    --output yaml
```

## Get the KMS Key ARN from an EBS Volume and Assign it to a Shell Variable

If there's a single volume, use this command:

```shell
export KMS_KEY_ID=$(aws ec2 describe-volumes \
    --region #AWS_REGION \
    --filters Name=attachment.instance-id,Values=$INSTANCE_ID \
    --query "Volumes[*].KmsKeyId" \
    --output text)
```

If there are multiple volumes, set the index of `Volumes` in the
`--query` parameter to 0 to get the first one.

```shell
export KMS_KEY_ID=$(aws ec2 describe-volumes \
    --region #AWS_REGION \
    --filters Name=attachment.instance-id,Values=$INSTANCE_ID \
    --query "Volumes[0].KmsKeyId" \
    --output text )
```

## KMS: Use Key ID to get Information

```shell
aws kms describe-key \
    --region $AWS_REGION \
    --key-id $KMS_KEY_ID \
    --output yaml
```

## KMS: Get the Alias (friendly name) of a KMS Key

```shell
aws kms list-aliases \
    --region $AWS_REGION \
    --key-id $KMS_KEY_ID \
    --query "Aliases[?TargetKeyId=='$KMS_KEY_ID'].AliasName" \
    --output yaml
```

## KMS: Get a list of all the KMS Key Aliases

```shell
aws kms list-aliases \
    --region $AWS_REGION \
    --query 'Aliases[?TargetKeyId=="$KMS_KEY_ID"].AliasName' \
    --output yaml
```
