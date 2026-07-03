# Levels — native client

Native Flutter client for Levels, built against the shared Supabase backend
(project `dnqwsgpkinieitiiikij`). Web (Chrome) is the only enabled platform for
now. See `CLAUDE.md` for the product and architecture brief.

## Setup

1. Copy `env.example.json` to `env.json` and fill in the publishable key
   (Supabase dashboard → Settings → API Keys). `env.json` is gitignored.
2. Run:

   ```
   flutter run -d chrome --dart-define-from-file=env.json
   ```

## Tests

```
flutter test
```

`test/auth_gate_test.dart` pins the auth-gate contract: no location outside
`/login` and `/signup` resolves without a live Supabase session.
