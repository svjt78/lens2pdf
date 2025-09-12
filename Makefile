.DEFAULT_GOAL := help

SUBDIR := mobile_app

.PHONY: help setup create pubget pods run run-android run-ios run-ios-sim boot-sim test analyze clean doctor print-permissions

help:
	@$(MAKE) -C $(SUBDIR) help

setup:
	@$(MAKE) -C $(SUBDIR) setup

create:
	@$(MAKE) -C $(SUBDIR) create

pubget:
	@$(MAKE) -C $(SUBDIR) pubget

pods:
	@$(MAKE) -C $(SUBDIR) pods

run:
	@$(MAKE) -C $(SUBDIR) run ARGS="$(ARGS)"

run-android:
	@$(MAKE) -C $(SUBDIR) run-android ARGS="$(ARGS)"

run-ios:
	@$(MAKE) -C $(SUBDIR) run-ios ARGS="$(ARGS)"

run-ios-sim:
	@$(MAKE) -C $(SUBDIR) run-ios-sim ARGS="$(ARGS)" $(if $(SIMULATOR_NAME),SIMULATOR_NAME="$(SIMULATOR_NAME)",)

boot-sim:
	@$(MAKE) -C $(SUBDIR) boot-sim $(if $(SIMULATOR_NAME),SIMULATOR_NAME="$(SIMULATOR_NAME)",)

test:
	@$(MAKE) -C $(SUBDIR) test ARGS="$(ARGS)"

analyze:
	@$(MAKE) -C $(SUBDIR) analyze ARGS="$(ARGS)"

clean:
	@$(MAKE) -C $(SUBDIR) clean

doctor:
	@$(MAKE) -C $(SUBDIR) doctor

print-permissions:
	@$(MAKE) -C $(SUBDIR) print-permissions
