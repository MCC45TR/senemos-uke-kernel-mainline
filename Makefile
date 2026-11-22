outdir ?= $(CURDIR)/build/srpm
source_worker := packaging/rpm/kernel/build-srpm.sh

.PHONY: validate verify-sources srpm
validate:
	bash tests/contracts/check-source-layout.sh

verify-sources:
	bash $(source_worker) --verify-sources

srpm:
	bash $(source_worker) "$(outdir)"
