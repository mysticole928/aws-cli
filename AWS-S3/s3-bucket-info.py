#!/usr/bin/env python3
"""
s3_bucket_info.py
Version: 1.0
Created: 2026-01-02

Usage:
  s3_bucket_info.py <bucket-name>

Description:
  Outputs configuration and metadata for an Amazon S3 bucket in YAML-like format.
  For each supported S3 "get-bucket-*" API, the script:
    - Prints the configuration if it exists
    - Prints "status: not configured" if the configuration is absent
    - Prints an error block for unexpected failures

  The bucket creation date is retrieved from `ListBuckets`, which is the only
  authoritative S3 API source for bucket creation time.

Output:
  YAML-style sections including:
    - Caller identity
    - Bucket creation date
    - Location, versioning, encryption
    - Public access block, policy, logging
    - Tags, lifecycle configuration
    - ACL, ownership controls, CORS, replication, and more

Requirements:
  - Python 3.9+
  - boto3 (uses standard AWS credential chain: env vars, config files, SSO, etc.)

Example:
  ./s3_bucket_info.py <s3-bucket-name>
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional, Tuple

import boto3
from botocore.exceptions import ClientError


# --- Minimal YAML emitter (avoids depending on PyYAML) -------------------------

def _is_scalar(x: Any) -> bool:
    return x is None or isinstance(x, (str, int, float, bool))


def _yaml_escape_str(s: str) -> str:
    # Conservative quoting: quote if it contains special characters or could be mis-typed by YAML
    needs_quotes = (
        s == ""
        or s.strip() != s
        or any(c in s for c in [":", "{", "}", "[", "]", ",", "#", "&", "*", "!", "|", ">", "%", "@", "`"])
        or "\n" in s
        or s.lower() in {"null", "true", "false", "yes", "no", "on", "off"}
        or s[0] in "-?@"
        or s.startswith(("~", "=", "<", ">", "\"", "'"))
    )
    if not needs_quotes:
        return s
    # Single-quote YAML escaping: single quote is doubled
    return "'" + s.replace("'", "''") + "'"


def yaml_info(obj: Any, indent: int = 0) -> str:
    sp = " " * indent
    if _is_scalar(obj):
        if obj is None:
            return "null"
        if isinstance(obj, bool):
            return "true" if obj else "false"
        if isinstance(obj, (int, float)):
            return str(obj)
        return _yaml_escape_str(str(obj))

    if isinstance(obj, list):
        if not obj:
            return "[]"
        lines: List[str] = []
        for item in obj:
            if _is_scalar(item):
                lines.append(f"{sp}- {yaml_info(item, 0)}")
            else:
                lines.append(f"{sp}- {yaml_info(item, indent + 2)}")
        return "\n".join(lines)

    if isinstance(obj, dict):
        if not obj:
            return "{}"
        lines = []
        for k, v in obj.items():
            key = str(k)
            if _is_scalar(v):
                lines.append(f"{sp}{key}: {yaml_info(v, 0)}")
            else:
                lines.append(f"{sp}{key}:")
                lines.append(yaml_info(v, indent + 2))
        return "\n".join(lines)

    # Fallback: stringify unknown objects
    return _yaml_escape_str(str(obj))


def print_section(title: str, content: Any) -> None:
    print("----")
    print(f"{title}:")
    yaml_output = yaml_info(content, indent=2)
    print(yaml_output if yaml_output else "  {}")


# --- S3 helpers ----------------------------------------------------------------

NOT_CONFIGURED_CODES = {
    "NoSuchBucket",
    "NoSuchTagSet",
    "NoSuchLifecycleConfiguration",
    "NoSuchPublicAccessBlockConfiguration",
    "NoSuchBucketPolicy",
    "NoSuchBucketLoggingStatus",
    "NoSuchReplicationConfiguration",
    "NoSuchEncryptionConfiguration",
    "NoSuchWebsiteConfiguration",
    "NoSuchCORSConfiguration",
    "NoSuchOwnershipControls",
    "NoSuchAccelerateConfiguration",
    "NoSuchRequestPaymentConfiguration",
    "ServerSideEncryptionConfigurationNotFoundError",
    "NotFound",
}


def classify_client_error(err: ClientError) -> Tuple[str, str]:
    code = err.response.get("Error", {}).get("Code", "Unknown")
    msg = err.response.get("Error", {}).get("Message", str(err))
    status = err.response.get("ResponseMetadata", {}).get("HTTPStatusCode")
    # Treat HTTP 404 as "not configured" for many bucket config getters
    if code in NOT_CONFIGURED_CODES or status == 404:
        return ("not configured", f"{code}: {msg}")
    return ("error", f"{code}: {msg}")


def get_bucket_creation_date(s3) -> Dict[str, Any]:
    # ListBuckets is global; returns CreationDate per bucket.
    resp = s3.list_buckets()
    # CreationDate is datetime; keep in RFC3339-ish with offset if present
    return resp


def find_bucket_in_listbuckets(resp: Dict[str, Any], bucket: str) -> Optional[Dict[str, Any]]:
    for b in resp.get("Buckets", []):
        if b.get("Name") == bucket:
            # Normalize datetime for printing
            cd = b.get("CreationDate")
            if isinstance(cd, datetime):
                # boto3 returns tz-aware; isoformat keeps offset
                b = dict(b)
                b["CreationDate"] = cd.isoformat()
            return b
    return None


def call_s3_getter(title: str, fn, *, postprocess=None) -> Tuple[str, Any]:
    try:
        data = fn()
        if postprocess:
            data = postprocess(data)
        return ("ok", data)
    except ClientError as e:
        kind, message = classify_client_error(e)
        if kind == "not configured":
            return ("not configured", {"status": "not configured"})
        return ("error", {"status": "error", "message": message})


def parse_policy(resp: Dict[str, Any]) -> Any:
    # get_bucket_policy returns {"Policy": "<json string>"}
    policy_str = resp.get("Policy")
    if not policy_str:
        return resp
    try:
        return json.loads(policy_str)
    except Exception:
        return {"Policy": policy_str}


def normalize_location(resp: Dict[str, Any]) -> Dict[str, Any]:
    # Per S3, LocationConstraint may be None/"": means us-east-1
    lc = resp.get("LocationConstraint")
    return {"LocationConstraint": lc if lc else "us-east-1"}


# --- Main ----------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        prog="s3_bucket_info.py",
        description="Output S3 bucket configuration and metadata in YAML-style output.",
    )
    parser.add_argument("bucket", help="S3 bucket name")
    args = parser.parse_args()
    bucket = args.bucket

    session = boto3.Session()
    sts = session.client("sts")
    s3 = session.client("s3")

    # Caller identity
    try:
        ident = sts.get_caller_identity()
        print_section("CallerIdentity", ident)
    except ClientError as e:
        print_section("CallerIdentity", {
                      "status": "error", "message": classify_client_error(e)[1]})

    # Creation date (ListBuckets)
    try:
        lb = s3.list_buckets()
        binfo = find_bucket_in_listbuckets(lb, bucket)
        if not binfo:
            print_section("Creation", {
                          "status": "error", "message": f"Bucket not found in ListBuckets for name: {bucket}"})
        else:
            print_section("Creation", {"Name": binfo.get(
                "Name"), "CreationDate": binfo.get("CreationDate")})
    except ClientError as e:
        print_section("Creation", {"status": "error",
                      "message": classify_client_error(e)[1]})

    # Core getters (your list + a few useful extras)
    getters: List[Tuple[str, Any, Optional[Any]]] = [
        ("Location", lambda: s3.get_bucket_location(
            Bucket=bucket), normalize_location),
        ("Versioning", lambda: s3.get_bucket_versioning(Bucket=bucket), None),
        ("Encryption", lambda: s3.get_bucket_encryption(Bucket=bucket), None),
        ("PublicAccessBlock", lambda: s3.get_public_access_block(Bucket=bucket), None),
        ("Policy", lambda: s3.get_bucket_policy(Bucket=bucket), parse_policy),
        ("Logging", lambda: s3.get_bucket_logging(Bucket=bucket), None),
        ("Tagging", lambda: s3.get_bucket_tagging(Bucket=bucket), None),
        ("Lifecycle", lambda: s3.get_bucket_lifecycle_configuration(Bucket=bucket), None),

        # Extras
        ("ACL", lambda: s3.get_bucket_acl(Bucket=bucket), None),
        ("PolicyStatus", lambda: s3.get_bucket_policy_status(Bucket=bucket), None),
        ("OwnershipControls", lambda: s3.get_bucket_ownership_controls(
            Bucket=bucket), None),
        ("CORS", lambda: s3.get_bucket_cors(Bucket=bucket), None),
        ("Website", lambda: s3.get_bucket_website(Bucket=bucket), None),
        ("Replication", lambda: s3.get_bucket_replication(Bucket=bucket), None),
        ("Accelerate", lambda: s3.get_bucket_accelerate_configuration(Bucket=bucket), None),
        ("RequestPayment", lambda: s3.get_bucket_request_payment(Bucket=bucket), None),
        ("ObjectLock", lambda: s3.get_object_lock_configuration(Bucket=bucket), None),
    ]

    for title, fn, post in getters:
        status, payload = call_s3_getter(title, fn, postprocess=post)
        print_section(title, payload)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
