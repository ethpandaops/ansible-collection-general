{{- /*
config.<network>: a small nginx (not ingress-nginx) behind one Ingress, for
Traefik ingress classes (gen_kubernetes_config_ingress_class). Each
config.files entry is an exact path proxied to https://<upstream><target>,
with the upstream's certificate verified. Responses are cached for a minute,
and a stale copy is served while GitHub or the bootnode is down. Any other
path is a 404. Replaces ingress.config.yaml.tpl's ExternalName Services and
per-path ingress-nginx Ingresses, which Traefik can't serve.
*/ -}}
{{- if .Values.config.enabled }}
{{- $name := "config-proxy" }}
{{- $labels := dict "app.kubernetes.io/name" $name "app.kubernetes.io/instance" .Release.Name }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $name }}
  labels: {{- toYaml $labels | nindent 4 }}
data:
  default.conf: |
    proxy_cache_path /tmp/cache levels=1:2 keys_zone=config:10m max_size=512m inactive=7d use_temp_path=off;
    # Upstreams are resolved per request, so the pod starts before the
    # bootnode's DNS exists.
    resolver kube-dns.kube-system.svc.cluster.local valid=60s ipv6=off;

    server {
      listen 8080;
      server_tokens off;

      proxy_http_version 1.1;
      proxy_ssl_server_name on;
      proxy_ssl_verify on;
      proxy_ssl_verify_depth 3;
      proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
      proxy_connect_timeout 5s;
      proxy_read_timeout 60s;
      proxy_hide_header Set-Cookie;
      proxy_ignore_headers Set-Cookie Cache-Control Expires Vary;
      proxy_cache config;
      proxy_cache_valid 200 60s;
      proxy_cache_valid 404 10s;
      proxy_cache_lock on;
      proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
      proxy_cache_background_update on;
      add_header X-Cache-Status $upstream_cache_status always;

      location = /healthz {
        access_log off;
        return 200 "ok\n";
      }
      {{- range .Values.config.files }}
      {{- if not (regexMatch "^[A-Za-z0-9._-]+$" .upstream) }}
      {{- fail (printf "config.files: upstream %q must be a plain host name" .upstream) }}
      {{- end }}
      {{- if not (regexMatch "^/[A-Za-z0-9._/-]*$" .path) }}
      {{- fail (printf "config.files: path %q must be an absolute path" .path) }}
      {{- end }}
      {{- if not (regexMatch "^/[A-Za-z0-9._/-]*$" .target) }}
      {{- fail (printf "config.files: target %q must be an absolute path" .target) }}
      {{- end }}

      location = {{ .path }} {
        limit_except GET { deny all; }
        set $config_upstream {{ .upstream }};
        proxy_ssl_name {{ .upstream }};
        proxy_set_header Host {{ .upstream }};
        # Uncompressed from upstream: the cache ignores Vary, so a gzip copy
        # fetched for one client would be served to every client.
        proxy_set_header Accept-Encoding "";
        proxy_pass https://$config_upstream{{ .target }};
      }
      {{- end }}

      location / {
        return 404;
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $name }}
  labels: {{- toYaml $labels | nindent 4 }}
spec:
  replicas: 1
  selector:
    matchLabels: {{- toYaml $labels | nindent 6 }}
  template:
    metadata:
      labels: {{- toYaml $labels | nindent 8 }}
      annotations:
        checksum/config: {{ .Values.config.files | toJson | sha256sum }}
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: nginx
          image: docker.io/nginxinc/nginx-unprivileged:1.30.4-alpine@sha256:adf5042a17f4ecdd200c595fa9ffd1be37efb18f89a830bd1a00e4ab4d59d42c
          command: ["nginx", "-g", "daemon off;"]
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              memory: 256Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: config
              mountPath: /etc/nginx/conf.d
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: config
          configMap:
            name: {{ $name }}
        - name: tmp
          emptyDir:
            sizeLimit: 600Mi
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}
  labels: {{- toYaml $labels | nindent 4 }}
spec:
  selector: {{- toYaml $labels | nindent 4 }}
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $name }}
  labels: {{- toYaml $labels | nindent 4 }}
  annotations:
    ethpandaops.io/exposure: "public"
spec:
  ingressClassName: {{ required "ingressClassName is required" .Values.ingressClassName }}
  rules:
    - host: "config.{{ .Values.domain }}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ $name }}
                port:
                  name: http
{{- end }}
