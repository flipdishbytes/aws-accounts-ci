# Purpose

This custom GitHub Action was created to read an AWS Account Id by `workload_name` and `ou_name`. It allows you to use the account id in your workflows without hardcoding it in YAML.

# Github Action: AWS Account ID Read `flipdishbytes/aws-accounts-ci@v1.1`

To use this action, add it to your pipeline workflow YAML file. See the example below.

### How it works?

1. Calls the Watchman API endpoint `/aws-governance/account-id` with the provided `workload_name` and `ou_name`.
2. Returns the matching `accountId` as an output.
3. Caches the response per repository so that repeat calls within the TTL window do not re-invoke the API.

**There is a separate role created for GitHub Actions which can be assumed only by Flipdish Org GitHub Actions repositories.**

**P.S. this role can't be assumed by any repo outside of the Flipdish GitHub Org.**

### Inputs

| Name             | Required | Default | Description                                                                                       |
| ---------------- | -------- | ------- | ------------------------------------------------------------------------------------------------- |
| `workload_name`  | yes      | —       | Name of the workload (e.g. `platform`, `de`).                                                     |
| `ou_name`        | yes      | —       | OU name (e.g. `ephemeral`, `prod`).                                                               |
| `cache_ttl_days` | no       | `30`    | How long a cached account id is reused before the action re-fetches it from the API. See below.   |

### Outputs

| Name        | Description       |
| ----------- | ----------------- |
| `accountId` | The AWS Account Id matching `${ou_name}-${workload_name}`. |

### Caching

Calls to the Watchman API are cached using [`actions/cache`](https://github.com/actions/cache) so that the API (and the Lambda behind it) is invoked at most once per `(ou_name, workload_name)` pair per `cache_ttl_days` window per repository.

Key facts to keep in mind:

- The cache is **scoped to a single repository**. Each repo that uses the action maintains its own cache; nothing is shared across the org.
- Each `(ou_name, workload_name)` combination gets its own cache entry, so a single repo can call the action multiple times for different accounts without collisions.
- The cache key looks like `aws-acct-<ou>-<workload>-<bucket>`, where `bucket = floor(days_since_epoch / cache_ttl_days)`. When the bucket number rolls over (every `cache_ttl_days` days) the next run does one fresh API call to repopulate the cache.
- Only successful responses are cached. A `200` with a valid 12-digit `accountId` is stored; `404`, other error statuses, and malformed responses are never cached, so a transient failure cannot poison subsequent runs.
- GitHub also evicts any cache entry that has not been accessed for 7 days, so quiet repos may repopulate sooner than the configured TTL.
- Branch scoping follows GitHub's normal cache rules: the default branch's cache is readable from any branch, and feature branches save into their own scope.

If you need to force a refresh ahead of schedule, override `cache_ttl_days` to a different number (this changes the key namespace and effectively starts a new cache).

### How to use?

#### `flipdishbytes/aws-accounts-ci@v1.1`

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
        uses: flipdishbytes/aws-accounts-ci@v1.1
        continue-on-error: false
        with:
          workload_name: 'platform'
          ou_name: 'ephemeral'
          # cache_ttl_days: '30'  # optional, defaults to 30

      - name: Assume role using OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ steps.account_id.outputs.accountId }}:role/github-ci-role
          aws-region: eu-west-1
```

On a cache hit the step's log will show `Cache hit: '<ou>-<workload>' account is: <accountId>` and the API will not be called. On a miss it will log the API response and save the result so the next run inside the same TTL window is served from cache.
