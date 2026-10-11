{{/* Which namespaces the Kyverno policies apply to. */}}
{{- define "platform.appNamespaces" }}
namespaceSelector:
  matchLabels:
    platform.macroer16/policies: enforced
{{- end }}
