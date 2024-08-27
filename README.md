# Purpose

This custom GitHub Action were created to read AWS Account Id by using workload and ou. It allows you to use accound id in your workflows without hardcoding it in yml.

# Github Action: AWS Account ID Read`flipdishbytes/aws-accounts-ci@v1.0`

To use this action, add it to your pipeline workflow YAML file. Here is example.

### How it works?

1. Downloads `aws-accounts.json` file from S3 bucket.
2. Search for `$ou_name-$workload_name` and provides `accountId` as output.

**There is separate role created for GitHub Actions which can be assumed only by Flipdish Org GitHub Actions repositories.**

**P.S. this role can't be assumed by any repo outside of Flipdish GitHub Org.**

### How to use?

#### `flipdishbytes/aws-accounts-ci@v1.0`

```yaml
name: GH Action workflow with reading AWS Account

on:
  pull_request:
    types:
      - opened
      - reopened
      - synchronize
      - edited
    branches:
      - 'main'

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Read AWS Account Id
        id: account_id
        uses: flipdishbytes/aws-accounts-ci@v1.0
        continue-on-error: false
        with:
          workload_name: 'delivery-enablement'
          ou_name: 'ephemeral'
      
      - name: Assume role using OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ steps.account_id.outputs.accountId }}:role/github-ci-role 
          aws-region: us-east-1
```
