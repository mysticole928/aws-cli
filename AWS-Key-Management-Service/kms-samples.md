# KMS CLI Snippets

Date: 2024-07-13

Some of these are duplicated my EC2 notes.
_By some, I mean all._

## To-Do: List Actions to get KMS ARNs

```shell
export KMS_KEY_ID=
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
