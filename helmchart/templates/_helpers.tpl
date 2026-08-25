{{- define "flask-aws-monitor.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "flask-aws-monitor.fullname" -}}
{{- $name := .Chart.Name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "flask-aws-monitor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "flask-aws-monitor.labels" -}}
helm.sh/chart: {{ include "flask-aws-monitor.chart" . }}
{{ include "flask-aws-monitor.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "flask-aws-monitor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flask-aws-monitor.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
