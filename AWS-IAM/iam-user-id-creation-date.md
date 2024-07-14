# Getting User ID Information from the CLI

<!--|    1         2         3         4         5         6         7         8         9      |-->
<!--|----|---------|---------|---------|---------|---------|---------|---------|---------|------|-->


Sometimes, there are things we need to know about an AWS account.  Yes, it's possible to find
informatin in the console.  That, however, can take some time and/or exploration.

## The Basics

To get all the information about a specific user service is `iam`, with the options `get-user` and
`--user-name <username>`.

> [!note]
> If `--user-name` is ommited, the command will return information from the CLI's user profile.

```shell
aws iam get-user --user-name YOUR_USER_NAME --output yaml
```

The interesting thing about `yaml` output is that it displays in alphabetical order.  

## Get Account Creation Date

### Quick and Easy Method

For a quick-and-easy solution, pipe the command through `jq` and use a `slice` with the array.

```shell
aws iam get-user | jq -r ".User.CreateDate[:10]"
```

`CreateDate` is an ISO 8601 date field.  
The JSON output looks like this: `"CreateDate": "2022-01-22T19:32:36+00:00"`

The `-r` option returns raw text.  (No quotes.)

- With the `-r` option: `2022-01-22`
- Without the `-r` option: `"2022-01-22"`

## An Elegant Method

For custom formatting,  use functionality built into `jq`.

The `CreateDate` field uses ISO 8601 formatting but it uses UTC offset.  The `fromdateiso8601`
function expects the "Z" suffiix instead of the `+00:00`.  

To fix that, `gsub("\\+00:00$"; "Z")` uses regex to change the suffix. 

This is piped into `fromdateiso8601` and that is reformatted by `strftime`.

```shell
aws iam get-user --output json | jq -r '
  .User.CreateDate
  | gsub("\\+00:00$"; "Z")
  | fromdateiso8601
  | strftime("%Y-%m-%d")
'
```

The output is: `2022-01-22`.

> [!note]
> Because the `jq` options are inside single `'` quotes, line continuation is automatic.

Using this method is useful when the date format needs to be converted.

