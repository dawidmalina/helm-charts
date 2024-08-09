# External Secrets Configuration

This repository helps define Kubernetes External Secrets in a more readable and very simplified syntax.

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

### Secret object configuration:
```
objects:
  name-of-the-secret:
    data:
      - secretKey: secret-key
        remoteRef: remote-secret-key
```

If `secretKey` and `remoteRef` are equal (the same) you can skip `remoteRef`:
```
objects:
  name-of-the-secret:
    data:
      - secretKey: secret-key
```

### Multiple objects keys in one secret

If value of the remote secrets is a json we can mount all objects as secret keys
```
objects:
  name-of-the-secret:
    dataFrom:
      - remoteRef: secret-key
```

or if we simply need one property (object) we can configure it as well:
```
objects:
  name-of-the-secret:
    data:
      - secretKey: secret-key-property
        remoteRef: secret-key
        property: secret-key-property
```
