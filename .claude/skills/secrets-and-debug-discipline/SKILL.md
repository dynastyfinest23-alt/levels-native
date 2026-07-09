---
name: secrets-and-debug-discipline
description: Enforce safe secret handling and disciplined debugging in any session that touches shell commands, API keys, Supabase, Edge Functions, or HTTP debugging. Use this skill whenever a command involves a credential (API key, service-role key, JWT, password, token), whenever an HTTP request fails, or whenever a multi-step PowerShell command is being constructed. Also trigger on any mention of "secrets set", "401", "403", "invoke", "curl", "Invoke-RestMethod", or key rotation.
---

# Secrets & Debug Discipline

These rules exist because violating them has real, demonstrated costs: repeated
key exposures forcing rotation cycles, unparseable commands, and multi-hour
debugging chains that pivoted between auth mechanisms before reading a single
error body. Follow them without exception.

## 1. Secrets never appear in visible commands or output

- NEVER construct a shell command containing a secret's literal value — not in
  a variable assignment (`$key = "sk-..."`), not in a header string, not in an
  argument, not anywhere that lands in scrollback, transcripts, or screenshots.
- Read secrets at runtime from environment variables or from local temp files
  that are (a) never echoed and (b) deleted when the task completes.
- If a secret must be entered exactly once (e.g. `supabase secrets set`), STOP
  and tell the user to type it directly into their own terminal. Never dictate
  a command with the key filled in, and never ask the user to paste a key into
  the conversation.
- Never print, log, or "confirm" a secret by displaying it. Confirm by name,
  type, length, or hash prefix only.
- If a secret does get exposed (in output, a file that was displayed, or the
  conversation), say so immediately and treat rotation as a blocking next step
  — do not defer it because debugging is "in progress."

## 2. Command construction limits

- PowerShell commands over ~900 bytes fail to parse in this environment. Never
  chain multi-step work into one long one-liner. Split into separate, short,
  individually-approvable commands and run them one at a time, showing the
  result of each before running the next.
- Prefer writing request payloads to a temp JSON file and referencing it
  (`--data "@file.json"`) over inlining large bodies with escaped quotes.

## 3. The debug ladder — read before pivoting

When an HTTP request or tool call fails:

1. Get the ACTUAL response: status code AND full body text. Use
   `curl.exe -s -S -w "\nHTTP_STATUS:%{http_code}"` or equivalent. Do not
   proceed on the exception message alone.
2. Only after the body is read, form a single hypothesis about which layer
   failed (gateway vs. own function code vs. upstream API vs. billing).
3. Test that ONE hypothesis with the smallest possible isolated check —
   e.g., replay an upstream API call directly, bypassing intermediate layers.
4. Never switch auth mechanisms, mint new tokens, or rotate keys as a
   debugging move until the current failure's body has been read and the
   layer identified. Each pivot without evidence multiplies rounds.

A correct early move that is easy to skip: if a function wraps an upstream
API (e.g. an Edge Function calling Anthropic), test the upstream call
directly with the same key and payload before debugging the wrapper's auth.

## 4. Irreversible-write protection

- Before invoking anything that caches or writes permanently on first success
  (e.g. one-row-per-loop caches), verify against a disposable test row first.
  Never spend a real production row's one-shot write on an unverified path.
- Clean up test rows and temp credential files at the end of the task, and
  confirm zero leftovers.
