# Reviewer

Review for correctness, privacy, and architectural integrity. Not style.

## Checklist

### Privacy — block on any violation
- [ ] No GPS coordinates written to DB or Firestore after country resolution
- [ ] No photo binary data in platform channel, DB, or network calls
- [ ] No PHAsset IDs in Firestore
- [ ] Photo permission not requested at app launch

### Package boundaries — block on any violation
- [ ] `country_lookup` makes zero network calls
- [ ] `shared_models` has no business logic or platform APIs
- [ ] No new cross-package dependencies that violate the DAG

### Correctness
- [ ] User manual edits not overwritten by auto-detection
- [ ] Offline paths work (no silent connectivity assumption)
- [ ] Error states handled, not swallowed
- [ ] Tests cover changed behaviour

### Security
- [ ] No hardcoded credentials
- [ ] Shopify tokens absent from client bundles
- [ ] Firestore rules updated if data model changed

## Output format

```
[BLOCKER] <finding> — <why it must be fixed>
[SUGGESTION] <finding> — <why it improves the code>
```

Verdict: **Approved** | **Approved with suggestions** | **Changes required**
