{{/*
Expand the name of the chart.
*/}}
{{- define "patroni-migration.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "patroni-migration.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "patroni-migration.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "patroni-migration.labels" -}}
helm.sh/chart: {{ include "patroni-migration.chart" . }}
{{ include "patroni-migration.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "patroni-migration.selectorLabels" -}}
app.kubernetes.io/name: {{ include "patroni-migration.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "patroni-migration.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "patroni-migration.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{- define "patroni-migration.dbenv" -}}
{{- if index .Values "from" . }}
value: {{ index .Values "from" . }}
{{- else }}
valueFrom:
  secretKeyRef:
    key: {{ index .Values "from" (printf "%s%s" . "SecretKey") }}
    name: {{ .Values.from.secret }}
{{- end }}
{{- end }}



{{- define "patroni-migration.ignoreRolesList" -}}
items:
    {{- range .Values.migrationJob.ignoreRoles }}
    - "ROLE {{ . }}"
    {{- end }}
{{- end }}