.PHONY: lint package sync

lint:
	pnpm lint

package:
ifeq ($(strip $(filter-out false 0,$(CI)) $(JENKINS_URL)),)
	pnpm build
endif

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
