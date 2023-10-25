# E2E tests

These are e2e tests for the install script. They create a remote VM on AWS using [e2e test framework](https://pkg.go.dev/github.com/DataDog/datadog-agent/test/new-e2e@main/pkg/utils/e2e) and run the installer script with:

- 4 possible modes:
  - `install` install latest Agent 7 RC
  - `upgrade5` install Agent 5 and upgrade to latest Agent 7 RC
  - `upgrade6` install Agent 6 and upgrade to latest Agent 7 RC
  - `upgrade7` install latest stable Agent 7 and upgrade to latest Agent 7 RC
- 3 possible flavors:
  - `datadog-agent` install Datadog Agent
  - `datadog-iot-agent` install Datadog IoT Agent
  - `datadog-dogstatsd` install Datadog dogstatsd

## Run locally

Use `go test` to run tests locally, from a shell wrapped in a valid aws session. This currently supports Datadog internal only configurations.

### Example: run install test, flavor datadog-agent, platform Amazon 2023

```shell
cd test/e2e && go test -timeout 0s . -v --run TestInstallSuite --flavor datadog-agent --platform Amazon_Linux_2023
```

## Run on CI

Manually run `e2e` stage on the CI and then manually upload results to CI Visibility running `e2e_test_upload` stage. You can override the script url setting `SCRIPT_URL` variable on manual test trigger
