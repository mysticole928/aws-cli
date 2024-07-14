# Amazon IAM

## Create an IAM Role

```shell
aws iam create-role \
  --role-name <-ROLE-NAME-> \
  --assume-role-policy-document file://<-POLICY-DOCUMENT->.json
```

## Attach a Policy to an IAM Role

Only one policy can be attached at a time.

```shell
aws iam attach-role-policy \
  --role-name <-ROLE-NAME-> \
  --policy-arn arn:aws:iam::<-ACCOUNT-NUMBER->:policy/<-POLICY-NAME->
```

## List all Custom IAM Policies

```shell
aws iam list-policies --scope Local \
  --query 'Policies[*].PolicyName | sort(@)' \
  --output text | tr '\t' '\n'
```

_To get AWS managed policies, change the_ `--scope` _to_ `All`.

Note: In JMESPath, the @ symbol is the element being processed.

The text output is separated with tabs.  
The `tr` command replaces it with newlines.

Alternatively, `--output table` to display the output with a column
heading.

```shell
aws iam list-policies --scope Local \
  --query 'Policies[*].PolicyName | sort(@)' \
  --output table
```

## Get the ARN of a Specific Policy

```shell
aws iam list-policies \
    --query "Policies[?PolicyName=='<--POLICY-NAME-->>'].[Arn]" \
    --output text
```

For automation, put the ARN in a shell variable.

```shell
export POLICY_ARN=$(aws iam list-policies \
    --query "Policies[?PolicyName=='<--POLICY-NAME-->>'].[Arn]" \
    --output text )
```

## List IAM Policies attached to an IAM Role

```shell
aws iam list-attached-role-policies \
    --role-name <--IAM-ROLE--> \
    --output yaml
```

## Create an Instance Profile

```shell
aws iam create-instance-profile \
    --instance-profile-name <--NEW-INSTANCE-PROFILE-NAME-->
```

## Add an IAM Role to an Instance Profile

```shell
aws iam add-role-to-instance-profile \
    --instance-profile-name <--INSTANCE-PROFILE-NAME--> \
    --role-name <--ROLE-NAME-->
```

## Verify Instance Profile Details

```shell
aws iam get-instance-profile \
    --instance-profile-name <--INSTANCE-PROFILE-NAME--> \
    --output yaml
```

## Associate Instsance Profile with EC2 Instance

This uses `ec2` instead of `iam`.

The `--iam-instance-profile` format is different from other
IAM artuments. It requires `Name=`.

```shell
aws ec2 associate-iam-instance-profile \
  --region us-west-2 \
  --instance-id <--INSTANCE-ID--> \
  --iam-instance-profile Name=<--INSTANCE-PROFILE-NAME--> \
  --output yaml
```

## Verify Instance Profile Attachment

```shell
aws ec2 describe-instances \
--region <--AWS-REGION--> \
--instance-ids <--INSTANCE-ID--> \
--query 'Reservations[*].Instances[*].
        IamInstanceProfile.Arn' \
--output text
```
