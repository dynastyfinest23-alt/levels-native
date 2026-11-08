-- Purpose: remove the Debt Cure Dashboard tables from the Levels project for
-- good (Noah, 2026-11-08: "should not be here"). Backed up first, row counts
-- verified against production (cards 11, action items 19, goals 4, profile 7,
-- payments 0): C:\Users\Administrator\Documents\Backups\debt-cure-dashboard\.
-- Runs after 20261108221046_lock_down_dcd_tables. Payments goes first because
-- it references cards.
BEGIN;

DROP TABLE IF EXISTS public.dcd_payments;
DROP TABLE IF EXISTS public.dcd_cards;
DROP TABLE IF EXISTS public.dcd_action_items;
DROP TABLE IF EXISTS public.dcd_goals;
DROP TABLE IF EXISTS public.dcd_profile;

COMMIT;
