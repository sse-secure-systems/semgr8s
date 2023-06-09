webhookName := semgr8s
image       :=  $(shell yq e '.deployment.image.repository' helm/values.yaml)
version     := $(shell yq e '.appVersion' helm/Chart.yaml)
tag         := $(image):$(version)

ns          := semgr8ns

all: uninstall install

.PHONY:build
build:
	@echo "####################"
	@echo "## $(@)"
	@echo "####################"
	docker build --platform=linux/amd64 -t $(tag) -f docker/Dockerfile .

.PHONY:push
push:
	@echo "####################"
	@echo "## $(@)"
	@echo "####################"
	docker push $(tag)

.PHONY:install
install:
	@echo "####################"
	@echo "## $(@)"
	@echo "####################"
	helm install semgr8s helm --create-namespace --namespace $(ns)

.PHONY:uninstall
uninstall:
	@echo "####################"
	@echo "## $(@)"
	@echo "####################"
	helm uninstall semgr8s -n $(ns)

.PHONY:annihilate
annihilate:
	@echo "####################"
	@echo "## $(@)"
	@echo "####################"
	helm uninstall semgr8s -n $(ns)
	kubectl delete ns $(ns)

.PHONY: test
test:
	@echo "####################"
	@echo "## $(@)"
	@echo "####################"
	-kubectl create -f tests/
	@echo
	-kubectl get pods -n test-semgr8s-passing
	@echo
	-kubectl get pods -n test-semgr8s-failing
	@echo
	-kubectl delete -f tests/
