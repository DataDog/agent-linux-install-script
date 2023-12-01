package pippo

import (
	"testing"

	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v2"
)

var data = `
a: Easy!
b:
c: 2
d: [3, 4]
`

func TestExample(t *testing.T) {
	config := map[string]any{}
	err := yaml.Unmarshal([]byte(data), &config)
	require.NoError(t, err)
	t.Logf("%v\n\n", config)
}
