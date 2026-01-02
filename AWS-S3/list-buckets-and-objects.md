# S3 Listing Buckets and Objects using the AWS CLI
Created: 2026-01-02

These examples use v2 of the `AWS CLI` and `yq`.

To format the `yaml` output, it is piped to `yq`.

`yq` a lightweight and portable command-line YAML, JSON, INI and XML processor. It has syntax 
similar to `jq` and works with `yaml`, `json`, `xml`, `ini`, `properties`, `csv`, and `tsv`. 

The `yq` website: [https://mikefarah.gitbook.io/yq](https://mikefarah.gitbook.io/yq)

## List Buckets with Creation Date

```shell
aws s3api list-buckets \
  --query 'Buckets[].{Name: Name, CreationDate: CreationDate}' \
  --output yaml | yq '.[] |= (.CreationDate |= format_datetime("2006-01-02 15:04:05 UTC"))'
```

This pipes the `yaml` output to `yq` to reformat the date to be human readable.

This sends the `yaml` in this shape:

```text
list
 ├─ map
 │   ├─ Name
 │   └─ CreationDate
 └─ map
     ├─ Name
     └─ CreationDate
```

The `.[]` iterates over each item in the list.
`|=` updates each element in place.
`.CreationDate |= ...` runs once per S3 Bucket

The output is formatted like this:

```text
- Name: bucket-a
  CreationDate: "2023-02-15 20:39:16 UTC"
- Name: bucket-b
  CreationDate: "2025-11-04 12:51:55 UTC"
```

## List S3 Objects in Bucket with Last Modified Date

`export S3_BUCKET_NAME=<s3-bucket-name>`

```shell
aws s3api list-objects-v2 \
  --bucket $S3_BUCKET_NAME \
  --query 'sort_by(Contents,&LastModified)[0].{Key: Key, LastModified: LastModified}' \
  --output yaml | yq '.LastModified |= format_datetime("2006-01-02 15:04:05 UTC")'
```



