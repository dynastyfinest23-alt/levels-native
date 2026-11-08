// PreToolUse gate for Supabase MCP execute_sql (added 2026-11-08, auto-mode hardening).
// execute_sql is allowlisted for verification reads (Noah, 2026-07-08), but the allow
// rule cannot see the query. This hook forces a human prompt for anything that can
// mutate production: DDL/DML keywords, or a call to one of the app's mutating RPCs.
// Fails closed: settings.json sets onFailure "block", and unparseable input asks.
let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let query = null;
  try {
    query = JSON.parse(raw).tool_input.query;
  } catch (_) {}
  const q = typeof query === 'string'
    ? query.replace(/--.*$/gm, ' ').replace(/\/\*[\s\S]*?\*\//g, ' ').toLowerCase()
    : null;
  const write = /\b(insert|update|delete|merge|upsert|alter|create|drop|truncate|grant|revoke|vacuum|reindex|cluster|copy|call|refresh|lock|security\s+label)\b|\bdo\s+\$|\bset\s+(role|session)\b/;
  // Mutating RPCs reachable via SELECT fn(...): process_*, apply_*, route_*, seed_*, handle_*, join_waitlist.
  const rpc = /\b(process|apply|route|seed|handle|join)_\w+\s*\(/;
  let reason = null;
  if (q === null) reason = 'execute_sql input could not be parsed; confirm manually.';
  else if (write.test(q)) reason = 'execute_sql contains a write/DDL keyword against production. CLAUDE.md: migrations are the only schema-change path.';
  else if (rpc.test(q)) reason = 'execute_sql calls a mutating RPC (process_/apply_/route_/seed_/handle_/join_) against production.';
  if (reason) {
    process.stdout.write(JSON.stringify({
      hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'ask', permissionDecisionReason: reason },
    }));
  }
  process.exit(0);
});
