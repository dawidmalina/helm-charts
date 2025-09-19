# External Secrets Configuration

This repository helps define Kubernetes External Secrets in a more readable and very simplified syntax.

## Breaking Changes

### v1.0.0
- **API Version Migration**: This chart now uses the stable `external-secrets.io/v1` API version instead of `external-secrets.io/v1beta1`
- Requires External Secrets Operator v0.8.0+ which supports the v1 API
- No changes to chart configuration are required as the API schema remains compatible

## Dependencies

[External Secret helm chart](https://charts.external-secrets.io) must be installed and default ClusterSecretStore configured.

## Configuration

### Global configuration:
- name of the cluster secret store for this cluster, ex `cloud-default-provider`
```
clusterSecretStore: default-provider
```

- how ofter check for secrets update, ex `1m`
```
refreshInterval: 1h
```

- add resource annotations, ex `argocd.argoproj.io/sync-wave: "-1"`
```
annotations:
  argocd.argoproj.io/sync-wave: "-1"
```

- configure global decoding strategy for automatic base64 decoding
```
decodingStrategy: "Auto"
```
Available values: `"Auto"`, `"Base64"`, `"None"`, or omitted (defaults to no decoding)

### Secret object configuration:
```
objects:
  name-of-the-secret:
    data:
      - secretKey: secret-key
        remoteRef: remote-secret-key
        decodingStrategy: "Base64"  # Optional: override global setting
```

If `secretKey` and `remoteRef` are equal (the same) you can skip `remoteRef`:
```
objects:
  name-of-the-secret:
    data:
      - secretKey: secret-key
        decodingStrategy: "Auto"  # Optional: decoding strategy for this key
```

### Multiple objects keys in one secret

If value of the remote secrets is a json we can mount all objects as secret keys
```
objects:
  name-of-the-secret:
    dataFrom:
      - remoteRef: secret-key
        decodingStrategy: "Auto"  # Optional: decoding strategy for this dataFrom
```

or if we simply need one property (object) we can configure it as well:
```
objects:
  name-of-the-secret:
    data:
      - secretKey: secret-key-property
        remoteRef: secret-key
        property: secret-key-property
        decodingStrategy: "Base64"  # Optional: decoding strategy for this property
```

### Decoding Strategy

The `decodingStrategy` parameter enables automatic decoding of base64-encoded secrets. It can be configured:

1. **Globally** - applies to all secrets unless overridden:
```yaml
decodingStrategy: "Auto"
```

2. **Per secret data entry** - overrides global setting:
```yaml
objects:
  my-secret:
    data:
      - secretKey: username
        remoteRef: db-username
        decodingStrategy: "Base64"
```

3. **Per dataFrom entry** - for JSON secrets:
```yaml
objects:
  my-secret:
    dataFrom:
      - remoteRef: json-secret
        decodingStrategy: "Auto"
```

**Available strategies:**
- `"Auto"` - Automatically detect and decode base64 content
- `"Base64"` - Force base64 decoding
- `"None"` - No decoding (default behavior)
- Omitted - No decoding applied
