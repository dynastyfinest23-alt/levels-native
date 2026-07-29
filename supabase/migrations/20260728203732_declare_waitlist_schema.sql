-- Catch-up migration: bring public.waitlist and public.join_waitlist() under
-- migration control. Both objects have existed in production since the
-- marketing-site waitlist form shipped (marketing-site/src/sections/Waitlist.tsx),
-- but were created through the SQL editor, so no migration declared them.
-- Found 2026-07-28 by diffing supabase_migrations.schema_migrations against
-- supabase/migrations/ (12 files, 12 rows, exact match, neither object present).
--
-- Every statement here is idempotent and reproduces the live definitions
-- verbatim as read from production on 2026-07-28 (information_schema.columns,
-- pg_constraint, pg_policies, pg_get_functiondef). Pushing this changes no
-- production behavior; it makes a rebuild from migrations reproduce the table.

BEGIN;

CREATE TABLE IF NOT EXISTS public.waitlist (
  id         UUID        NOT NULL DEFAULT gen_random_uuid(),
  email      TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source     TEXT        NOT NULL DEFAULT 'marketing-site',
  CONSTRAINT waitlist_pkey     PRIMARY KEY (id),
  CONSTRAINT waitlist_email_key UNIQUE (email)
);

ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY has no IF NOT EXISTS (migration rule 2).
DROP POLICY IF EXISTS "Allow anonymous waitlist signup" ON public.waitlist;
CREATE POLICY "Allow anonymous waitlist signup"
  ON public.waitlist FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Reproduced exactly as deployed. NOTE: this policy is inert by construction.
-- `id` is the waitlist row's own gen_random_uuid() primary key, not a
-- users.id, so `auth.uid() = id` can never be true and no client role can
-- read this table. Only postgres/service_role can. That is a safe outcome
-- (no email harvesting), so this migration declares it rather than changing
-- it. Flagged in ACTION-FOR-NOAH.md for a deliberate decision.
DROP POLICY IF EXISTS "Allow users to read own waitlist entry" ON public.waitlist;
CREATE POLICY "Allow users to read own waitlist entry"
  ON public.waitlist FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- SECURITY DEFINER so the anon marketing-site client can insert without a
-- session; search_path pinned per the standing hardening rule. The ON CONFLICT
-- makes a repeat signup a silent no-op rather than a 409 to the browser.
CREATE OR REPLACE FUNCTION public.join_waitlist(p_email text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_result json;
BEGIN
  INSERT INTO waitlist (email, source)
  VALUES (p_email, 'marketing-site')
  ON CONFLICT (email) DO NOTHING
  RETURNING json_build_object('success', true, 'email', email, 'created_at', created_at) INTO v_result;

  IF v_result IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Already on the waitlist');
  END IF;

  RETURN v_result;
END;
$function$;

COMMIT;
