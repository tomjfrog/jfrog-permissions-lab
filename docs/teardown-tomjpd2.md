# Teardown lab on tomjpd2

**Destructive.** Run only with explicit approval. Uses `--server-id tomjpd2`.

## Order

1. Delete Access permissions `isplt-plt-*`:

```bash
for p in A B C D E F G H I; do
  jf api --server-id tomjpd2 -X DELETE "/access/api/v2/permissions/isplt-plt-${p}" 2>/dev/null || true
done
```

2. Delete project repos, then projects `isplt-prj-*`:

```bash
for pk in isplt-prj-full isplt-prj-noreports isplt-prj-nobuild isplt-prj-noartifact isplt-prj-developer; do
  for r in "${pk}-npm" "${pk}-npm-local"; do
    jf api --server-id tomjpd2 -X DELETE "/artifactory/api/repositories/${r}" 2>/dev/null || true
  done
done
for pk in isplt-prj-full isplt-prj-noreports isplt-prj-nobuild isplt-prj-noartifact isplt-prj-developer; do
  jf api --server-id tomjpd2 -X DELETE "/access/api/v1/projects/${pk}" 2>/dev/null || true
done
```

3. Delete platform repos (empty first):

```bash
for r in isplt-npm-local isplt-maven-local isplt-docker-local isplt-npm isplt-maven isplt-docker; do
  jf api --server-id tomjpd2 -X DELETE "/artifactory/api/repositories/${r}" 2>/dev/null || true
done
```

4. Delete builds (optional):

```bash
jf api --server-id tomjpd2 -X DELETE "/artifactory/api/build/isplt-lab-npm-flagged?deleteAll=1"
```

5. Delete persona users:

```bash
for u in lab-plt-{a,b,c,d,e,f,g,h,i} lab-prj-{full,noreports,nobuild,noartifact,developer}; do
  jf api --server-id tomjpd2 -X DELETE "/access/api/v2/users/${u}" 2>/dev/null || true
done
```

6. Revoke tokens created for harness (`jf access-token-create` IDs from audit).

7. Remove local `lab/tokens/` and `harness/out/`.

## Prefix convention

All lab keys start with `isplt-` for grep-based verification before delete.
