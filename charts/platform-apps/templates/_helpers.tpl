{{/* Settings every Application shares: automatic sync, self-healing, retries. */}}
{{- define "apps.syncPolicy" -}}
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  retry:
    limit: 10
    backoff: { duration: 10s, factor: 2, maxDuration: 3m }
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
{{- end -}}

{{- define "apps.meta" -}}
namespace: argocd
finalizers:
  - resources-finalizer.argocd.argoproj.io
{{- end -}}
