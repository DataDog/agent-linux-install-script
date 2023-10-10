# E2E installer tests

These tests use the e2e framework from `datadog-agent` repository

## Run tests locally

Use `go test` to run a test on one flavor and platform from `test/e2e`

```bash
go test -timeout 0s -run TestInstallFipsScriptSuite github.com/DataDog/agent-linux-install-script/test/e2e -v --flavor datadog-agent --targetPlatform Ubuntu_22_04
```
