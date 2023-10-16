// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.
package e2e

import "fmt"

type agentFlavor string

func (af *agentFlavor) String() string {
	return string(*af)
}

func (af *agentFlavor) Set(value string) error {
	if len(*af) > 0 {
		return fmt.Errorf("flavor flag already set to %s while trying to set to %s", *af, value)
	}
	*af = agentFlavor(value)
	return nil
}

const (
	agentFlavorDatadogAgent     agentFlavor = "datadog-agent"
	agentFlavorDatadogIOTAgent  agentFlavor = "datadog-iot-agent"
	agentFlavorDatadogDogstatsd agentFlavor = "datadog-dogstatsd"
)
