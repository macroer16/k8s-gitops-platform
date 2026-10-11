{{- define "due.tag" -}}{{ .Values.images.tag | default .Chart.AppVersion }}{{- end -}}

{{- define "due.labels" -}}
app.kubernetes.io/part-of: due
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/* Locked-down container settings shared by every container in the chart. */}}
{{- define "due.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
capabilities:
  drop: ["ALL"]
{{- end -}}
