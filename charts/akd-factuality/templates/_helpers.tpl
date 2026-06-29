{{- define "akd-factuality.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "akd-factuality.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "akd-factuality.ollamaBaseUrl" -}}
{{- if .Values.ollama.useInCluster -}}
http://{{ .Values.ollama.inClusterServiceName }}:{{ .Values.ollama.inClusterPort }}
{{- else -}}
{{ .Values.ollama.externalBaseUrl }}
{{- end -}}
{{- end -}}
