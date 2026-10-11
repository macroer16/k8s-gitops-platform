`scripts/make-secrets.sh` writes this cluster's SealedSecrets here. They are encrypted with the
cluster's sealed-secrets public key, so they are safe to commit: only the controller in that
cluster can decrypt them. The controller's private key is backed up outside the repo
(`~/.config/k8s-gitops-platform/`) so a rebuilt cluster can still read them.
