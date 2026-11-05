targets := lint package sync
.PHONY: $(targets)

lint:
	mvn compile checkstyle:check pmd:check

package:
	mvn clean compile checkstyle:check pmd:check package

ifneq ($(filter sync,$(MAKECMDGOALS)),)
ifneq ($(firstword $(MAKECMDGOALS)):$(words $(MAKECMDGOALS)),sync:2)
$(error Usage: make sync UPSTREAM)
endif
export SYNC_UPSTREAM := $(word 2,$(MAKECMDGOALS))
ifneq ($(filter $(targets),$(SYNC_UPSTREAM)),)
$(error Usage: make sync UPSTREAM)
endif

.PHONY: $(SYNC_UPSTREAM)
$(SYNC_UPSTREAM): ;
endif

sync:
	./ci-sync-upstream.sh "$$SYNC_UPSTREAM" --local
