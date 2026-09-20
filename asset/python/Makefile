.PHONY: lint package

lint:
	uvx --offline ruff check --fix --output-format concise .
	uvx --offline ruff format .
	@output="$$(uvx --offline vulture main.py tanqi --exclude '*/tanqi/mq/types.py,*/tanqi/eao/base.py,*/tanqi/service/base.py,*/tanqi/service/model_service.py' --min-confidence 60 --ignore-decorators '@api_router.*,@app.*,@model_validator' 2>&1)"; \
	status=$$?; \
	if [ $$status -ne 0 ] && [ $$status -ne 3 ]; then \
		printf '%s\n' "$$output"; \
		exit $$status; \
	fi; \
	unused="$$(printf '%s\n' "$$output" | grep -E 'unused (function|method) ' | tr '\134' '/' || true)"; \
	if [ -n "$$unused" ]; then \
		printf '%s\n' "$$unused"; \
		exit 1; \
	fi

package: lint
