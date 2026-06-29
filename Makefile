.PHONY: deploy deploy-all template

ENV ?= dev
NAMESPACE ?= akd-$(ENV)
ENV_VALUES := environments/$(ENV)/values.yaml

# Extracts the top-level key matching $(SERVICE) out of the environment's merged
# values.yaml (e.g. `akd-api:` block) into a temp file scoped to that chart.
define extract_values
	yq eval '.["$(SERVICE)"]' $(ENV_VALUES) > /tmp/$(SERVICE)-$(ENV).values.yaml
endef

deploy:
	@test -n "$(SERVICE)" || (echo "usage: make deploy SERVICE=akd-api ENV=dev" && exit 1)
	$(call extract_values)
	helm upgrade --install $(SERVICE) ./charts/$(SERVICE) \
		--namespace $(NAMESPACE) --create-namespace \
		--atomic --timeout 5m \
		-f charts/$(SERVICE)/values.yaml \
		-f /tmp/$(SERVICE)-$(ENV).values.yaml

deploy-all:
	$(MAKE) deploy SERVICE=akd-storage ENV=$(ENV)
	$(MAKE) deploy SERVICE=akd-auth ENV=$(ENV)
	@if [ "$$(yq eval '.["akd-inference"].enabled' $(ENV_VALUES))" = "true" ]; then \
		$(MAKE) deploy SERVICE=akd-inference ENV=$(ENV); \
	fi
	$(MAKE) deploy SERVICE=akd-factuality ENV=$(ENV)
	$(MAKE) deploy SERVICE=akd-api ENV=$(ENV)

template:
	@test -n "$(SERVICE)" || (echo "usage: make template SERVICE=akd-api ENV=dev" && exit 1)
	$(call extract_values)
	helm template $(SERVICE) ./charts/$(SERVICE) \
		-f charts/$(SERVICE)/values.yaml \
		-f /tmp/$(SERVICE)-$(ENV).values.yaml
