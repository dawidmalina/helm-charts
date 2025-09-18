{{/*
Expand the name of the chart.
*/}}
{{- define "system-upgrade.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "system-upgrade.fullname" -}}
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
{{- define "system-upgrade.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "system-upgrade.labels" -}}
helm.sh/chart: {{ include "system-upgrade.chart" . }}
{{ include "system-upgrade.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "system-upgrade.selectorLabels" -}}
app.kubernetes.io/name: {{ include "system-upgrade.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use for the controller
*/}}
{{- define "system-upgrade.serviceAccountName" -}}
{{- if .Values.controller.serviceAccount.create }}
{{- default (include "system-upgrade.fullname" .) .Values.controller.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.controller.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the namespace to use
*/}}
{{- define "system-upgrade.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Create the controller image name
*/}}
{{- define "system-upgrade.controllerImage" -}}
{{- $registry := .Values.controller.image.registry }}
{{- $repository := .Values.controller.image.repository }}
{{- $tag := .Values.controller.image.tag | default .Chart.AppVersion }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Create the kubectl image name
*/}}
{{- define "system-upgrade.kubectlImage" -}}
{{- $registry := .Values.kubectl.image.registry }}
{{- $repository := .Values.kubectl.image.repository }}
{{- $tag := .Values.kubectl.image.tag }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Create common tolerations for system components
*/}}
{{- define "system-upgrade.tolerations" -}}
{{- with .Values.tolerations }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Create fixed controller role name
*/}}
{{- define "system-upgrade.controllerRoleName" -}}
system-upgrade-controller
{{- end }}

{{/*
Create fixed drainer role name
*/}}
{{- define "system-upgrade.drainerRoleName" -}}
system-upgrade-controller-drainer
{{- end }}

