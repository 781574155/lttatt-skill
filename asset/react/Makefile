.PHONY: lint package

lint:
	pnpm lint

package:
ifeq ($(strip $(filter-out false 0,$(CI)) $(JENKINS_URL)),)
	pnpm build
endif
