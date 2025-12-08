{{/*
Expand the name of the chart.
*/}}
{{- define "image-preloader.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "image-preloader.fullname" -}}
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
{{- define "image-preloader.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "image-preloader.labels" -}}
helm.sh/chart: {{ include "image-preloader.chart" . }}
{{ include "image-preloader.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "image-preloader.selectorLabels" -}}
app.kubernetes.io/name: {{ include "image-preloader.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "image-preloader.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "image-preloader.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Convert image name to tar filename
Example: selenium/standalone-firefox:4.23.1-20240820 -> selenium/standalone-firefox_4.23.1-20240820.tar
Example: harbor.example.com/hub/selenium/standalone-firefox:4.23.1-20240820 -> hub/selenium/standalone-firefox_4.23.1-20240820.tar
*/}}
{{- define "image-preloader.imageToFilename" -}}
{{- $parts := splitList ":" . }}
{{- $imageNameWithPath := index $parts 0 }}
{{- $tag := "latest" }}
{{- if gt (len $parts) 1 }}
{{- $tag = index $parts 1 }}
{{- end }}
{{- $pathParts := splitList "/" $imageNameWithPath }}
{{- $imagePath := $imageNameWithPath }}
{{- if contains "." (index $pathParts 0) }}
{{- $imagePath = join "/" (rest $pathParts) }}
{{- end }}
{{- printf "%s_%s.tar" $imagePath $tag }}
{{- end }}
