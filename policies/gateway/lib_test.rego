package gateway.lib_test

import rego.v1

import data.gateway.lib

# The catalog moves from the policy bundle (data.catalog) to the registry's data
# bundle (data.registry.catalog); either may load first, so the policy reads the
# registry's and falls back to its own.
test_the_registry_catalog_comes_first if {
	lib.catalog == {"models": {"m": {}}} with data.registry.catalog as {"models": {"m": {}}}
		with data.catalog as {"models": {"old": {}}}
}

test_without_the_registry_catalog_the_policy_bundle_one if {
	lib.catalog == {"models": {"old": {}}} with data.registry as {}
		with data.catalog as {"models": {"old": {}}}
}
