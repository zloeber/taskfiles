#!/usr/bin/python
import os
import sys
import hvac
import boto3
import boto3.utils
import json


def extract_role_name_from_arn(role_arn: str):
    # Split the ARN string by '/' and get the last element
    role_name = role_arn.split("/")[-1]
    return role_name


def validate_vault_aws_roles(client: hvac.Client, session: boto3.Session):
    # Get all the AWS roles from Vault
    response = client.secrets.aws.list_roles(mount_point="auth/aws")
    roles = response["data"]["keys"]
    report = []
    iam_client = session.client("iam")

    # Validate each role
    for role in roles:
        # Get the role's ID from Vault
        this_role_data = client.auth.aws.read_role(role)
        bound_iam_principal_arn = None
        bound_iam_principal_id = None

        if len(this_role_data["bound_iam_principal_arn"]):
            bound_iam_principal_arn = this_role_data["bound_iam_principal_arn"][0]
        if len(this_role_data["bound_iam_principal_id"]):
            bound_iam_principal_id = this_role_data["bound_iam_principal_id"][0]
        role_exists = False
        role_name = extract_role_name_from_arn(bound_iam_principal_arn)
        # Check if the role exists in AWS
        try:
            aws_role_data = iam_client.get_role(RoleName=role_name)
            role_exists = True
        except iam_client.exceptions.NoSuchEntityException:
            role_exists = False
        except Exception as err:
            print(err)

        # Get the role's ID from AWS
        aws_role_id = None
        if role_exists:
            aws_role_id = aws_role_data["Role"]["RoleId"]

        # Compare the role's ID in Vault and AWS
        if role_exists and bound_iam_principal_id == aws_role_id:
            status = "Valid"
        elif role_exists and bound_iam_principal_id != aws_role_id:
            status = "ID Changed"
        else:
            status = "Role Not Found"

        # Add the role's validation result to the report
        report.append(
            {
                "Role": role,
                "bound_iam_principal_arn": bound_iam_principal_arn,
                "bound_iam_principal_id": bound_iam_principal_id,
                "aws_role_id": aws_role_id,
                "Status": status,
            }
        )

    return report


# Example usage
vault_url = os.getenv("VAULT_ADDR", "http://127.0.0.1:8200")
vault_token = os.getenv("VAULT_TOKEN")
aws_region = "us-east-1"

try:
    vault_client = hvac.Client(url=vault_url, token=vault_token)
except Exception as err:
    print(f"Unable to authenticate with Vault: {err}")
    sys.exit(1)

# Initialize AWS session
try:
    aws_session = boto3.Session(region_name=aws_region)
except Exception as err:
    print(f"Unable to authenticate with AWS: {err}")
    sys.exit(1)

report = validate_vault_aws_roles(vault_client, aws_session)

# Print the report
print(json.dumps(report, indent=2))
