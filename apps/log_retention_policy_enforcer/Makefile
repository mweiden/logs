include ../../common.mk

SERVICE_NAME := log-retention-policy-enforcer
ZIP_FILE := LogRetentionPolicyEnforcer_App.zip
ZIP_KEY := $(SERVICE_NAME)/$(ZIP_FILE)
LAMBDA_BUCKET := `jq -r .logs_lambda_bucket $(SECRETS_FILE)`


default: build

.PHONY: install
install:
	virtualenv -p python3 venv
	venv/bin/pip install -r requirements.txt

terraform-%:
	. venv/bin/activate && terraform $(*) \
		-var-file $(SECRETS_FILE) \
		-var path_to_zip_file=$(ZIP_KEY) \
		-var service_name=$(SERVICE_NAME) \
		$(TF_OPTIONS)

.PHONY: plan
plan:
	TF_OPTIONS=-detailed-exitcode $(MAKE) terraform-plan

.PHONY: test
test:
	. venv/bin/activate && python -m unittest discover -s test -p 'test_*.py'


.PHONY: build
build: install
	rm -rf target
	mkdir target
	cp app.py target/
	venv/bin/pip install -r requirements.txt -t target/ --upgrade
	cd target && zip -r ../$(ZIP_FILE)  *


.PHONY: deploy
deploy: build
	aws s3 cp $(ZIP_FILE) s3://$(LAMBDA_BUCKET)/$(ZIP_KEY)
	$(MAKE) terraform-apply
	aws lambda update-function-code --function-name log-retention-policy-enforcer --s3-bucket $(LAMBDA_BUCKET) --s3-key $(ZIP_KEY)

