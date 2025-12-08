# SPIRE AWS Auth Plugin

A SPIRE CredentialComposer plugin that enables fine-grained AWS IAM Role assumption for SPIFFE-identified workloads. It injects specific OIDC claims (`aud`, `azp`, session tags, and source identity) into JWT-SVIDs based on authorization rules stored in S3.

This plugin allows workloads to assume IAM roles based on their SPIFFE identity.
## Architecture

The plugin acts as a Policy Enforcement Point (PEP) during JWT issuance:

1. **Intercept**: Listens for `ComposeWorkloadJWTSVID` calls
2. **Filter**: Detects requests for AWS-specific audiences format: `SPIFFE/<AccountID>:<DBType>:<Cluster>:<User>`
3. **Authorize**: Fetches a JSON rule object from S3 keyed by the workload's SPIFFE ID
4. **Mint**: If authorized, injects AWS-specific claims required for `sts:AssumeRoleWithWebIdentity` with session tagging

## Installation

### Configuration

#### Plugin Configuration (`server.conf`)

Add the following to SPIRE Server configuration:

```hcl
CredentialComposer "aws_auth" {
    plugin_cmd = "/path/to/plugin"
    plugin_data {
        # S3 Bucket containing the authorization rules
        rules_bucket = "spire-auth-rules-<ACCOUNT_ID>"
        aws_region   = "us-east-1"
    }
}
```

#### Authorization Rules (S3)

Rules are stored in S3 as JSON lists. The S3 Object Key must match the SPIFFE ID path (excluding the scheme).

**Example:**
- SPIFFE ID: `spiffe://example.org/ns/app/sa/test-workload`
- S3 Key: `example.org/ns/app/sa/test-workload`

**Schema:**

```json
[
  {
    "spiffe_id": "spiffe://example.org/ns/app/sa/test-workload",
    "aws_account_id": "123456789012",
    "db_type": "aurora",
    "db_cluster": "my-cluster",
    "db_user": "read-only"
  }
]
```

## Usage

### 1. Workload Request

The workload must request a JWT-SVID with a specific audience format matching its desired access:

```bash
# Format: SPIFFE/<AccountID>:<DBType>:<Cluster>:<User>
AUDIENCE="SPIFFE/123456789012:aurora:my-cluster:read-only"

/opt/spire/bin/spire-agent api fetch jwt \
    -audience "$AUDIENCE" \
    -socketPath /run/spire/agent-sockets/socket
```

### 2. Token Claims Output

The plugin generates a token compatible with AWS OIDC Trust Policies:

```json
{
  "sub": "spiffe://example.org/ns/app/sa/test-workload",
  "aud": [
    "SPIFFE/123456789012:aurora:my-cluster:read-only",  // Client validation
    "SPIFFE/123456789012"                               // AWS IAM validation
  ],
  "azp": "SPIFFE/123456789012",                         // Required for multi-aud
  "https://aws.amazon.com/tags": {
    "principal_tags": {
      "Target": ["aurora"],
      "DB": ["my-cluster"],
      "DBuser": ["read-only"]
    }
  },
  "https://aws.amazon.com/source_identity": "app+test-workload"
}
```

### 3. AWS IAM Trust Policy

Configure IAM Role with the following trust policy to accept the SPIRE-issued tokens:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/<OIDC_URL>"
      },
      "Action": [
        "sts:AssumeRoleWithWebIdentity",
        "sts:TagSession",
        "sts:SetSourceIdentity"
      ],
      "Condition": {
        "StringEquals": {
          "<OIDC_URL>:aud": "SPIFFE/<ACCOUNT_ID>",
          "aws:RequestTag/Target": "aurora"
        }
      }
    }
  ]
}
```

## Building

### Binary Build

```bash
# Build binary for Linux AMD64
GOOS=linux GOARCH=amd64 go build -o spire-aws-auth-plugin .
```

### Docker Image

```bash
# Build Docker image for K8s init container deployment
docker build -t spire-aws-auth-plugin:latest .

# or build image for publishing to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 074122282848.dkr.ecr.us-east-1.amazonaws.com

docker build \
  --platform linux/amd64 \
  -t 074122282848.dkr.ecr.us-east-1.amazonaws.com/spire-aws-auth-plugin:v0.1.0 \
  .

docker push 074122282848.dkr.ecr.us-east-1.amazonaws.com/spire-aws-auth-plugin:v0.1.0
```

## Deployment

### Kubernetes

The plugin can be deployed as an init container that copies the binary to a shared volume with the SPIRE Server:

```yaml
initContainers:
- name: aws-auth-plugin
  image: spire-aws-auth-plugin:latest
  command: ["cp", "/plugin/spire-aws-auth-plugin", "/spire-plugins/"]
  volumeMounts:
  - name: spire-plugins
    mountPath: /spire-plugins
```

### Standalone

For standalone deployments, ensure the plugin binary is accessible to the SPIRE Server process and update the `plugin_cmd` path in the configuration.