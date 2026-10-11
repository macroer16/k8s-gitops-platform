.PHONY: tools up down status argocd-password grafana-password loadtest policy-test lint

tools:            ## install kubectl, helm, k3d and kubeseal (Linux/WSL2)
	scripts/install-tools.sh

up:               ## create the local cluster and install everything
	scripts/up.sh

down:             ## delete the local cluster
	scripts/down.sh

status:           ## show every ArgoCD application
	kubectl -n argocd get applications

argocd-password:
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

grafana-password:
	@kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo

loadtest:         ## run the k6 load test inside the cluster and watch the API scale
	tests/loadtest.sh

policy-test:      ## prove the Kyverno policies block bad workloads
	tests/policy-tests.sh

lint:             ## the same static checks CI runs
	helm lint charts/*
