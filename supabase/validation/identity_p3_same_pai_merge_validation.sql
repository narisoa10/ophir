-- =============================================================================
-- Identity P3 validation: automatic same-PAI canonical reconciliation
-- BEGIN … ROLLBACK. Requires 20260818150000_plaid_same_pai_canonical_reconcile.sql
-- PASS via SELECT (not NOTICE).
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_user_id uuid := 'a0b30000-0000-4000-8000-000000000001';
  v_user_other uuid := 'a0b30000-0000-4000-8000-000000000002';
  v_item_id uuid := 'a0b30000-0000-4000-8000-000000000010';
  v_item_b uuid := 'a0b30000-0000-4000-8000-000000000012';
  v_item_other uuid := 'a0b30000-0000-4000-8000-000000000011';
  v_secret_id uuid := 'a0b30000-0000-4000-8000-0000000000ff';
  v_secret_b uuid := 'a0b30000-0000-4000-8000-0000000000fd';
  v_secret_other uuid := 'a0b30000-0000-4000-8000-0000000000fe';
  v_identity_id uuid := 'a0b30000-0000-4000-8000-0000000000aa';
  v_identity_other uuid := 'a0b30000-0000-4000-8000-0000000000ab';

  v_acc_a uuid;
  v_acc_b uuid;
  v_acc_c uuid;
  v_acc_manual uuid;
  v_acc_foreign uuid;
  v_can_a uuid;
  v_can_b uuid;
  v_can_c uuid;
  v_survivor uuid;
  v_auth uuid;
  v_result jsonb;
  v_result2 jsonb;
  v_synced integer;
  v_op_id uuid;
  v_op_amount numeric;
  v_op_account uuid;
  v_op_source text;
  v_op_amount_after numeric;
  v_op_account_after uuid;
  v_op_source_after text;
  v_def_p3 text;
  v_def_persist text;
  v_def_ensure text;
  v_def_p1 text;
  v_def_f text;
  v_def_lock text;
  v_pos_ensure integer;
  v_pos_reconcile integer;
  v_pos_lock integer;
  v_pos_upsert integer;
  v_pos_for_update integer;
  v_pos_ensure_in_p3 integer;
  v_def_p3_nocomment text;
  v_tie_ts timestamptz := timestamptz '2026-01-01 12:00:00+00';
  v_canons integer;
  v_auth_count integer;
  v_sec_count integer;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id IN (v_user_id, v_user_other)) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: auth.users';
  END IF;

  -- ----- Structural / grants / wiring (P3-29..34, 43..53, 54..64) -----
  SELECT pg_get_functiondef(
    'public.plaid_reconcile_account_identity_by_pai(uuid,uuid)'::regprocedure
  ) INTO v_def_p3;
  SELECT pg_get_functiondef(
    'public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)'::regprocedure
  ) INTO v_def_persist;
  SELECT pg_get_functiondef(
    'public.plaid_ensure_account_identity(uuid,uuid)'::regprocedure
  ) INTO v_def_ensure;
  SELECT pg_get_functiondef(
    'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)'::regprocedure
  ) INTO v_def_p1;
  SELECT pg_get_functiondef(
    'public.plaid_lock_account_identity_pai_group(uuid,text)'::regprocedure
  ) INTO v_def_lock;

  IF v_def_p3 IS NULL THEN
    RAISE EXCEPTION 'P3-26: reconcile helper missing';
  END IF;
  IF v_def_lock IS NULL THEN
    RAISE EXCEPTION 'P3-61: shared PAI group lock helper missing';
  END IF;
  IF position('plaid_link_canonical_financial_accounts' IN v_def_p3) = 0 THEN
    RAISE EXCEPTION 'P3-26: P1 merge not reused';
  END IF;
  IF position('plaid_ensure_account_identity' IN v_def_p3) = 0 THEN
    RAISE EXCEPTION 'P3-25: P2 ensure not reused for siblings';
  END IF;
  IF position('plaid_lock_account_identity_pai_group' IN v_def_p3) = 0 THEN
    RAISE EXCEPTION 'P3-28: reconcile missing shared PAI advisory helper';
  END IF;
  IF position('pg_advisory_xact_lock' IN v_def_lock) = 0 THEN
    RAISE EXCEPTION 'P3-28: expected transaction-scoped PAI advisory lock';
  END IF;
  IF position('order by members.linked_at asc, members.account_id asc' IN lower(v_def_p3)) = 0 THEN
    RAISE EXCEPTION 'P3-14: group-wide authority order missing';
  END IF;

  IF position('plaid_ensure_account_identity' IN v_def_persist) = 0 THEN
    RAISE EXCEPTION 'P3-29: persist missing ensure';
  END IF;
  IF position('plaid_reconcile_account_identity_by_pai' IN v_def_persist) = 0 THEN
    RAISE EXCEPTION 'P3-29: persist missing reconcile';
  END IF;
  v_pos_ensure := position('plaid_ensure_account_identity' IN v_def_persist);
  v_pos_reconcile := position('plaid_reconcile_account_identity_by_pai' IN v_def_persist);
  IF v_pos_ensure = 0 OR v_pos_reconcile = 0 OR v_pos_ensure > v_pos_reconcile THEN
    RAISE EXCEPTION 'P3-29: ensure must precede reconcile in persist';
  END IF;

  -- P3 failure aborts TX: no EXCEPTION handler swallowing reconcile in persist.
  IF position('exception when' IN lower(v_def_persist)) > 0 THEN
    RAISE EXCEPTION 'P3-30: persist must not catch reconcile failures';
  END IF;

  IF position('array_agg' IN lower(v_def_p3)) = 0
     OR position('order by siblings.id' IN lower(v_def_p3)) = 0 THEN
    RAISE EXCEPTION 'P3-31: deterministic sibling ordering missing';
  END IF;

  -- ----- Lock-order structural (P3-54..P3-64) -----
  -- P3-54 / P3-56: effective PAI via coalesce(existing, incoming) before upsert
  IF position('v_effective_pai' IN v_def_persist) = 0 THEN
    RAISE EXCEPTION 'P3-54: persist missing effective PAI derivation';
  END IF;
  IF position('coalesce(v_existing_pai, v_persistent_account_id)' IN lower(v_def_persist)) = 0
     AND position('coalesce(v_existing_pai,v_persistent_account_id)' IN lower(v_def_persist)) = 0 THEN
    RAISE EXCEPTION 'P3-56: effective PAI must coalesce(existing, incoming)';
  END IF;
  IF position('accounts.plaid_account_id = v_plaid_account_id' IN lower(v_def_persist)) = 0 THEN
    RAISE EXCEPTION 'P3-54: pre-upsert PAI lookup must use (user_id, plaid_account_id)';
  END IF;

  -- P3-55: advisory before account upsert
  v_pos_lock := position('plaid_lock_account_identity_pai_group' IN v_def_persist);
  v_pos_upsert := position('insert into public.accounts' IN lower(v_def_persist));
  IF v_pos_lock = 0 OR v_pos_upsert = 0 OR v_pos_lock > v_pos_upsert THEN
    RAISE EXCEPTION 'P3-55: PAI group advisory must precede account upsert';
  END IF;

  -- P3-59: null effective PAI skips advisory (conditional on non-null)
  IF position('if v_effective_pai is not null' IN lower(v_def_persist)) = 0 THEN
    RAISE EXCEPTION 'P3-59: null effective PAI must skip group advisory';
  END IF;

  -- P3-60: reconcile advisory before first executable FOR UPDATE.
  -- Strip `-- …` line comments first: pg_get_functiondef preserves comments that
  -- mention FOR UPDATE before the real lock statement (false-negative trap).
  v_def_p3_nocomment := regexp_replace(lower(v_def_p3), '--[^\n]*', '', 'g');
  v_pos_lock := position(
    'plaid_lock_account_identity_pai_group' IN v_def_p3_nocomment
  );
  v_pos_for_update := position('for update' IN v_def_p3_nocomment);
  IF v_pos_lock = 0
     OR v_pos_for_update = 0
     OR v_pos_lock > v_pos_for_update
  THEN
    RAISE EXCEPTION 'P3-60: reconcile must acquire advisory before first FOR UPDATE';
  END IF;

  -- P3-61: shared key helper used by both; helper owns hashtext expression
  IF position('plaid_lock_account_identity_pai_group' IN v_def_persist) = 0 THEN
    RAISE EXCEPTION 'P3-61: persist must use shared PAI lock helper';
  END IF;
  IF position('hashtext' IN lower(v_def_lock)) = 0
     OR position('chr(1)' IN v_def_lock) = 0 THEN
    RAISE EXCEPTION 'P3-61: lock helper key derivation incomplete';
  END IF;
  IF NOT has_function_privilege(
    'service_role',
    'public.plaid_lock_account_identity_pai_group(uuid,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P3-61: service_role missing EXECUTE on lock helper';
  END IF;
  IF has_function_privilege(
    'authenticated',
    'public.plaid_lock_account_identity_pai_group(uuid,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P3-61: authenticated must not EXECUTE lock helper';
  END IF;

  -- P3-62: sibling ensure only after advisory in reconcile
  -- (same comment-stripped text as P3-60 so offsets remain comparable)
  v_pos_ensure_in_p3 := position(
    'plaid_ensure_account_identity' IN v_def_p3_nocomment
  );
  IF v_pos_lock = 0 OR v_pos_ensure_in_p3 = 0 OR v_pos_lock > v_pos_ensure_in_p3 THEN
    RAISE EXCEPTION 'P3-62: sibling ensure must follow group advisory';
  END IF;

  -- P3-63: deterministic group ordering
  IF position('array_agg(gid order by gid)' IN lower(v_def_p3)) = 0 THEN
    RAISE EXCEPTION 'P3-63: group account ordering not deterministic';
  END IF;

  -- P3-64: P1/P2 bodies not rewritten by P3 orchestration markers
  IF position('plaid_lock_account_identity_pai_group' IN v_def_ensure) > 0 THEN
    RAISE EXCEPTION 'P3-64: P2 ensure must remain unchanged (no P3 lock helper)';
  END IF;
  IF position('plaid_lock_account_identity_pai_group' IN v_def_p1) > 0 THEN
    RAISE EXCEPTION 'P3-64: P1 merge must remain unchanged (no P3 lock helper)';
  END IF;
  IF position('v_survivor_canonical_id' IN v_def_p1) = 0 THEN
    RAISE EXCEPTION 'P3-64: P1 merge survivor logic missing';
  END IF;
  IF position('for update' IN lower(v_def_ensure)) = 0 THEN
    RAISE EXCEPTION 'P3-64: P2 ensure FOR UPDATE contract missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_canonical_financial_account_members_active_account_uidx'
  ) THEN
    RAISE EXCEPTION 'P3-33: active membership unique missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_canonical_financial_account_members_active_authority_uidx'
  ) THEN
    RAISE EXCEPTION 'P3-34: active authority unique missing';
  END IF;

  -- Signature: same arg types as historical persist (P3-43)
  IF to_regprocedure(
    'public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)'
  ) IS NULL THEN
    RAISE EXCEPTION 'P3-43: persist signature changed';
  END IF;

  IF NOT has_function_privilege(
    'service_role',
    'public.plaid_reconcile_account_identity_by_pai(uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P3-44: service_role missing EXECUTE on reconcile';
  END IF;
  IF has_function_privilege(
    'authenticated',
    'public.plaid_reconcile_account_identity_by_pai(uuid,uuid)',
    'EXECUTE'
  ) OR has_function_privilege(
    'anon',
    'public.plaid_reconcile_account_identity_by_pai(uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P3-44: anon/authenticated must not EXECUTE reconcile';
  END IF;

  -- No P4 backfill in P3 migration body (helper must not scan all users)
  IF position('from public.accounts' IN lower(v_def_p3)) = 0 THEN
    RAISE EXCEPTION 'P3 helper missing accounts access';
  END IF;
  IF position('for update of' IN lower(v_def_p3)) > 0
     OR position('full-table' IN lower(v_def_p3)) > 0 THEN
    RAISE EXCEPTION 'P3-45: unexpected mass-scan marker';
  END IF;
  -- P3 migration file must not call reconcile for all accounts at apply time:
  -- structural: helper is only CREATE OR REPLACE FUNCTION, no DO backfill block in migration
  -- (validated by absence of mass UPDATE on members outside function body — N/A here)

  IF position('plaid_link_canonical_financial_accounts' IN v_def_ensure) > 0 THEN
    RAISE EXCEPTION 'P3-28: P2 ensure must remain merge-free';
  END IF;
  IF position('persistent_account_id' IN v_def_ensure) > 0 THEN
    RAISE EXCEPTION 'P3-28: P2 ensure must not scan PAI';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)'::regprocedure
  ) INTO v_def_f;
  IF position('stage_f_v2' IN v_def_f) = 0 THEN
    RAISE EXCEPTION 'P3-40: Stage F v2 body not present';
  END IF;
  IF position('plaid_reconcile_account_identity_by_pai' IN v_def_f) > 0 THEN
    RAISE EXCEPTION 'P3-40: Stage F must not call P3';
  END IF;

  -- Stage G hook still on P1 success paths
  IF position(
    'plaid_reconcile_confirmed_internal_transfers_for_user' IN v_def_p1
  ) = 0 THEN
    RAISE EXCEPTION 'P3-42: P1 missing Stage G consistency hook call site';
  END IF;

  IF position('plaid_resolve' IN lower(v_def_p3)) > 0
     OR position('stage_e' IN lower(v_def_p3)) > 0 THEN
    RAISE EXCEPTION 'P3-39: P3 must not invoke Stage E';
  END IF;
  IF position('materialize' IN lower(v_def_p3)) > 0 THEN
    RAISE EXCEPTION 'P3-38: P3 must not invoke Stage D materialize';
  END IF;

  -- Auth fixtures
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    (
      '00000000-0000-0000-0000-000000000000', v_user_id,
      'authenticated', 'authenticated',
      'identity-p3-' || v_user_id::text || '@ophir.invalid',
      extensions.crypt('identity-p3-not-used', extensions.gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      now(), now(), '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000', v_user_other,
      'authenticated', 'authenticated',
      'identity-p3-' || v_user_other::text || '@ophir.invalid',
      extensions.crypt('identity-p3-not-used', extensions.gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      now(), now(), '', '', '', ''
    );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) VALUES
    (
      v_identity_id, v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', 'identity-p3-' || v_user_id::text || '@ophir.invalid'),
      'email', v_user_id::text, now(), now(), now()
    ),
    (
      v_identity_other, v_user_other,
      jsonb_build_object('sub', v_user_other::text, 'email', 'identity-p3-' || v_user_other::text || '@ophir.invalid'),
      'email', v_user_other::text, now(), now(), now()
    );

  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id)
     OR NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_other) THEN
    RAISE EXCEPTION 'FIXTURE: profile missing';
  END IF;

  INSERT INTO public.plaid_items (
    id, user_id, plaid_environment, plaid_item_id, access_token_secret_id
  ) VALUES
    (v_item_id, v_user_id, 'sandbox', 'identity-p3-item-a-' || v_user_id::text, v_secret_id),
    (v_item_b, v_user_id, 'sandbox', 'identity-p3-item-b-' || v_user_id::text, v_secret_b),
    (v_item_other, v_user_other, 'sandbox', 'identity-p3-item-' || v_user_other::text, v_secret_other);

  CREATE FUNCTION pg_temp.make_plaid(
    p_user_id uuid,
    p_item_id uuid,
    p_plaid_account_id text,
    p_pai text,
    p_archived boolean DEFAULT false
  ) RETURNS uuid
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    v_id uuid := gen_random_uuid();
  BEGIN
    INSERT INTO public.accounts (
      id, user_id, name, type, currency_code,
      initial_balance, icon_key, color_key, sort_order, is_archived,
      plaid_item_id, plaid_account_id, plaid_type, plaid_subtype,
      persistent_account_id
    ) VALUES (
      v_id, p_user_id, 'P3 ' || p_plaid_account_id, 'bank', 'USD',
      0, 'bank', 'blue', 0, p_archived,
      p_item_id, p_plaid_account_id, 'depository', 'checking',
      p_pai
    );
    RETURN v_id;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.active_topology(p_ids uuid[])
  RETURNS TABLE (canon_count integer, auth_count integer, sec_count integer)
  LANGUAGE sql
  AS $fn$
    SELECT
      count(DISTINCT m.canonical_account_id)::integer,
      count(*) FILTER (WHERE m.role = 'authoritative')::integer,
      count(*) FILTER (WHERE m.role = 'secondary')::integer
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.unlinked_at IS NULL
      AND m.account_id = ANY (p_ids);
  $fn$;

  -- ===== P3-1..P3-6 two siblings =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-two-a', 'pai-two');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-two-b', 'pai-two');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);

  SELECT m.canonical_account_id INTO v_can_a
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL;
  SELECT m.canonical_account_id INTO v_can_b
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL;
  IF v_can_a IS NOT DISTINCT FROM v_can_b THEN
    RAISE EXCEPTION 'P3-1 setup: expected separate singletons';
  END IF;

  -- Force older linked_at on A so A is group authority
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2025-01-01 00:00:00+00'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2025-06-01 00:00:00+00'
  WHERE account_id = v_acc_b AND unlinked_at IS NULL;

  -- Historical membership on A's canonical (P3-6)
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin, linked_at, unlinked_at
  ) VALUES (
    v_user_id, v_can_a, v_acc_a, 'secondary', 'user_confirmed',
    timestamptz '2024-01-01 00:00:00+00', timestamptz '2024-06-01 00:00:00+00'
  );

  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_b);
  IF coalesce(v_result->>'status', '') <> 'reconciled' THEN
    RAISE EXCEPTION 'P3-1: expected reconciled, got %', v_result;
  END IF;

  SELECT * INTO v_canons, v_auth_count, v_sec_count
  FROM pg_temp.active_topology(ARRAY[v_acc_a, v_acc_b]);
  IF v_canons <> 1 THEN
    RAISE EXCEPTION 'P3-1: expected one canonical, got %', v_canons;
  END IF;
  IF v_auth_count <> 1 THEN
    RAISE EXCEPTION 'P3-2: expected one authoritative, got %', v_auth_count;
  END IF;
  IF v_sec_count <> 1 THEN
    RAISE EXCEPTION 'P3-3: expected one secondary, got %', v_sec_count;
  END IF;

  SELECT m.account_id, m.canonical_account_id INTO v_auth, v_survivor
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b)
    AND m.unlinked_at IS NULL
    AND m.role = 'authoritative';
  IF v_auth IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P3-4/P3-7: authority must be older A, got %', v_auth;
  END IF;
  IF v_survivor IS DISTINCT FROM v_can_a THEN
    RAISE EXCEPTION 'P3-4: survivor canonical must be A''s canonical';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b
      AND m.unlinked_at IS NULL
      AND m.role = 'secondary'
      AND m.link_origin = 'persistent_account_identity'
  ) THEN
    RAISE EXCEPTION 'P3-5: secondary merge evidence missing persistent_account_identity';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.canonical_account_id = v_can_a
      AND m.account_id = v_acc_a
      AND m.unlinked_at IS NOT NULL
      AND m.link_origin = 'user_confirmed'
  ) THEN
    RAISE EXCEPTION 'P3-6: historical unlinked membership not preserved';
  END IF;

  -- ===== P3-8 tie linked_at → lower account_id =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-tie-a', 'pai-tie');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-tie-b', 'pai-tie');
  -- Ensure lower id wins: swap so v_acc_a < v_acc_b lexicographically if needed
  IF v_acc_a > v_acc_b THEN
    -- rename locals: keep smaller as expected winner
    v_acc_c := v_acc_a;
    v_acc_a := v_acc_b;
    v_acc_b := v_acc_c;
  END IF;
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = v_tie_ts
  WHERE account_id IN (v_acc_a, v_acc_b) AND unlinked_at IS NULL;

  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_b);
  SELECT m.account_id INTO v_auth
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b)
    AND m.unlinked_at IS NULL AND m.role = 'authoritative';
  IF v_auth IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P3-8: tie must pick lower account_id, got % want %', v_auth, v_acc_a;
  END IF;

  -- ===== P3-9 new sync_bootstrap does not steal =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-steal-a', 'pai-steal');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2024-01-01 00:00:00+00', link_origin = 'user_confirmed'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;

  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-steal-b', 'pai-steal');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  -- B is fresher sync_bootstrap
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = now(), link_origin = 'sync_bootstrap'
  WHERE account_id = v_acc_b AND unlinked_at IS NULL;

  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_b);
  SELECT m.account_id INTO v_auth
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b)
    AND m.unlinked_at IS NULL AND m.role = 'authoritative';
  IF v_auth IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P3-9: established authority stolen by sync_bootstrap';
  END IF;

  -- ===== P3-10 reversed payload order =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-rev-a', 'pai-rev');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-rev-b', 'pai-rev');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2023-01-01 00:00:00+00'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2023-06-01 00:00:00+00'
  WHERE account_id = v_acc_b AND unlinked_at IS NULL;

  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  SELECT m.account_id INTO v_auth
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b)
    AND m.unlinked_at IS NULL AND m.role = 'authoritative';
  IF v_auth IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P3-10a: unexpected winner from A payload';
  END IF;

  -- Reset as separate singletons again for B-first
  -- (already merged; create fresh pair)
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-rev2-a', 'pai-rev2');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-rev2-b', 'pai-rev2');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2023-01-01 00:00:00+00'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2023-06-01 00:00:00+00'
  WHERE account_id = v_acc_b AND unlinked_at IS NULL;

  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_b);
  SELECT m.account_id INTO v_auth
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b)
    AND m.unlinked_at IS NULL AND m.role = 'authoritative';
  IF v_auth IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P3-10: reversed payload changed winner';
  END IF;

  -- ===== P3-11..15 three siblings =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-tri-a', 'pai-tri');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-tri-b', 'pai-tri');
  v_acc_c := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-tri-c', 'pai-tri');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_c);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2022-01-01 00:00:00+00'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2022-02-01 00:00:00+00'
  WHERE account_id = v_acc_b AND unlinked_at IS NULL;
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2022-03-01 00:00:00+00'
  WHERE account_id = v_acc_c AND unlinked_at IS NULL;

  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_c);
  SELECT * INTO v_canons, v_auth_count, v_sec_count
  FROM pg_temp.active_topology(ARRAY[v_acc_a, v_acc_b, v_acc_c]);
  IF v_canons <> 1 THEN
    RAISE EXCEPTION 'P3-11: expected one canonical, got %', v_canons;
  END IF;
  IF v_auth_count <> 1 THEN
    RAISE EXCEPTION 'P3-12: expected one authority, got %', v_auth_count;
  END IF;
  IF v_sec_count <> 2 THEN
    RAISE EXCEPTION 'P3-13: expected two secondary, got %', v_sec_count;
  END IF;
  SELECT m.account_id INTO v_auth
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b, v_acc_c)
    AND m.unlinked_at IS NULL AND m.role = 'authoritative';
  IF v_auth IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P3-14: group-wide authority not A';
  END IF;

  v_result2 := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_b);
  IF coalesce(v_result2->>'status', '') <> 'already_reconciled' THEN
    RAISE EXCEPTION 'P3-15: expected already_reconciled, got %', v_result2;
  END IF;
  SELECT * INTO v_canons, v_auth_count, v_sec_count
  FROM pg_temp.active_topology(ARRAY[v_acc_a, v_acc_b, v_acc_c]);
  IF v_canons <> 1 OR v_auth_count <> 1 OR v_sec_count <> 2 THEN
    RAISE EXCEPTION 'P3-15: topology flipped on repeat';
  END IF;

  -- ===== P3-16..21 PAI fencing =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-diff-a', 'pai-diff-1');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-diff-b', 'pai-diff-2');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  SELECT m.canonical_account_id INTO v_can_a
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL;
  SELECT m.canonical_account_id INTO v_can_b
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL;
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'already_reconciled' THEN
    RAISE EXCEPTION 'P3-16: different PAI must not merge, got %', v_result;
  END IF;
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'P3-16: different PAI topologies merged';
  END IF;

  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-nullcur', NULL);
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-nullcur-sib', 'pai-nullcur');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'not_applicable' THEN
    RAISE EXCEPTION 'P3-17: null current PAI expected not_applicable, got %', v_result;
  END IF;

  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-nullsib-a', 'pai-nullsib');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-nullsib-b', NULL);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'already_reconciled' THEN
    RAISE EXCEPTION 'P3-18: null sibling must not match, got %', v_result;
  END IF;
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'P3-18: null sibling incorrectly merged';
  END IF;

  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-bothnull-a', NULL);
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-bothnull-b', NULL);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'not_applicable' THEN
    RAISE EXCEPTION 'P3-19: both null expected not_applicable, got %', v_result;
  END IF;

  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-foreign-a', 'pai-foreign');
  v_acc_foreign := pg_temp.make_plaid(v_user_other, v_item_other, 'p3-foreign-b', 'pai-foreign');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_other, v_acc_foreign);
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'already_reconciled' THEN
    RAISE EXCEPTION 'P3-20: foreign same PAI must not merge, got %', v_result;
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.plaid_canonical_financial_account_members ma
    JOIN public.plaid_canonical_financial_account_members mb
      ON ma.canonical_account_id = mb.canonical_account_id
     AND ma.unlinked_at IS NULL AND mb.unlinked_at IS NULL
    WHERE ma.account_id = v_acc_a AND mb.account_id = v_acc_foreign
  ) THEN
    RAISE EXCEPTION 'P3-20: cross-user merge occurred';
  END IF;

  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived,
    persistent_account_id
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P3 Manual PAI-like', 'cash', 'USD',
    0, 'cash', 'green', 0, false,
    'pai-manual-trap'
  ) RETURNING id INTO v_acc_manual;
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-manual-trap', 'pai-manual-trap');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'already_reconciled' THEN
    RAISE EXCEPTION 'P3-21: manual must not participate, got %', v_result;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_manual AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P3-21: manual gained membership';
  END IF;

  -- ===== P3-22 natural PAI first-fill via persist =====
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-fill-sib', 'pai-fill');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2021-01-01 00:00:00+00'
  WHERE account_id = v_acc_b AND unlinked_at IS NULL;

  -- Pre-existing account without PAI (unmembered until persist)
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived,
    plaid_item_id, plaid_account_id, plaid_type, plaid_subtype,
    persistent_account_id
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P3 Fill Target', 'bank', 'USD',
    0, 'bank', 'blue', 0, false,
    v_item_id, 'p3-fill-target', 'depository', 'checking',
    NULL
  ) RETURNING id INTO v_acc_a;

  v_synced := public.plaid_persist_accounts_sync(
    v_user_id, v_item_id, 'ins_p3', 'P3 Bank', null, null, null, now(),
    jsonb_build_array(
      jsonb_build_object(
        'plaid_account_id', 'p3-fill-target',
        'name', 'P3 Fill Target',
        'plaid_type', 'depository',
        'plaid_subtype', 'checking',
        'currency_code', 'USD',
        'current_balance', 10,
        'available_balance', 10,
        'persistent_account_id', 'pai-fill'
      )
    )
  );
  IF v_synced <> 1 THEN
    RAISE EXCEPTION 'P3-22: synced_count=%', v_synced;
  END IF;
  IF (
    SELECT a.persistent_account_id FROM public.accounts a WHERE a.id = v_acc_a
  ) IS DISTINCT FROM 'pai-fill' THEN
    RAISE EXCEPTION 'P3-22: PAI not filled';
  END IF;
  SELECT * INTO v_canons, v_auth_count, v_sec_count
  FROM pg_temp.active_topology(ARRAY[v_acc_a, v_acc_b]);
  IF v_canons <> 1 OR v_auth_count <> 1 OR v_sec_count <> 1 THEN
    RAISE EXCEPTION 'P3-22: first-fill merge failed canons=% auth=% sec=%',
      v_canons, v_auth_count, v_sec_count;
  END IF;
  SELECT m.account_id INTO v_auth
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b)
    AND m.unlinked_at IS NULL AND m.role = 'authoritative';
  IF v_auth IS DISTINCT FROM v_acc_b THEN
    RAISE EXCEPTION 'P3-22: established sibling should remain authority';
  END IF;

  -- ===== P3-23 first-wins PAI not overwritten =====
  UPDATE public.accounts SET persistent_account_id = 'pai-keep'
  WHERE id = v_acc_a;
  -- Need a sibling with pai-keep already? Just assert persist coalesce
  v_synced := public.plaid_persist_accounts_sync(
    v_user_id, v_item_id, 'ins_p3', 'P3 Bank', null, null, null, now(),
    jsonb_build_array(
      jsonb_build_object(
        'plaid_account_id', 'p3-fill-target',
        'name', 'P3 Fill Target',
        'plaid_type', 'depository',
        'plaid_subtype', 'checking',
        'currency_code', 'USD',
        'current_balance', 11,
        'available_balance', 11,
        'persistent_account_id', 'pai-other-incoming'
      )
    )
  );
  IF (
    SELECT a.persistent_account_id FROM public.accounts a WHERE a.id = v_acc_a
  ) IS DISTINCT FROM 'pai-keep' THEN
    RAISE EXCEPTION 'P3-23: existing PAI overwritten';
  END IF;

  -- ===== P3-24 metadata-only repeat =====
  SELECT m.canonical_account_id INTO v_survivor
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL;
  v_synced := public.plaid_persist_accounts_sync(
    v_user_id, v_item_id, 'ins_p3', 'P3 Bank', null, null, null, now(),
    jsonb_build_array(
      jsonb_build_object(
        'plaid_account_id', 'p3-fill-target',
        'name', 'P3 Fill Target Renamed',
        'plaid_type', 'depository',
        'plaid_subtype', 'checking',
        'currency_code', 'USD',
        'current_balance', 12,
        'available_balance', 12,
        'persistent_account_id', 'pai-keep'
      )
    )
  );
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P3-24: topology changed on metadata sync';
  END IF;

  -- ===== P3-25 unmembered sibling ensure =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-unmem-a', 'pai-unmem');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-unmem-b', 'pai-unmem');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2020-01-01 00:00:00+00'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P3-25 setup: B unexpectedly membered';
  END IF;
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'reconciled' THEN
    RAISE EXCEPTION 'P3-25: expected reconciled with ensure+merge, got %', v_result;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL AND m.role = 'secondary'
  ) THEN
    RAISE EXCEPTION 'P3-25: unmembered sibling not brought in';
  END IF;

  -- ===== P3-27 already same canonical =====
  v_result2 := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_b);
  IF coalesce(v_result2->>'status', '') <> 'already_reconciled' THEN
    RAISE EXCEPTION 'P3-27: expected already_reconciled, got %', v_result2;
  END IF;

  -- ===== P3-35 archived sibling =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-arch-a', 'pai-arch', false);
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-arch-b', 'pai-arch', true);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2019-01-01 00:00:00+00'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2019-06-01 00:00:00+00'
  WHERE account_id = v_acc_b AND unlinked_at IS NULL;
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  SELECT * INTO v_canons, v_auth_count, v_sec_count
  FROM pg_temp.active_topology(ARRAY[v_acc_a, v_acc_b]);
  IF v_canons <> 1 OR v_auth_count <> 1 OR v_sec_count <> 1 THEN
    RAISE EXCEPTION 'P3-35: archived sibling must participate';
  END IF;

  -- ===== P3-36 Item connectivity not used (structural + still-mergeable while row exists) =====
  IF position('connection' IN lower(v_def_p3)) > 0
     OR position('needs_reauth' IN lower(v_def_p3)) > 0
     OR position('error_code' IN lower(v_def_p3)) > 0 THEN
    RAISE EXCEPTION 'P3-36: Item health used as identity criterion';
  END IF;

  -- ===== P3-37 operations unchanged =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-op-a', 'pai-op');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p3-op-b', 'pai-op');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2018-01-01 00:00:00+00'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  v_op_id := gen_random_uuid();
  INSERT INTO public.operations (
    id, user_id, from_account_id, to_account_id, type, amount,
    currency_code, occurred_at, source, category_id, archived_at,
    category_overridden, recurrence, is_recurring
  ) VALUES (
    v_op_id, v_user_id, v_acc_b, null, 'expense', 42.50,
    'USD', DATE '2026-08-01', 'plaid', null, null,
    false, 'none', false
  );
  SELECT amount, from_account_id, source
  INTO v_op_amount, v_op_account, v_op_source
  FROM public.operations WHERE id = v_op_id;

  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  SELECT amount, from_account_id, source
  INTO v_op_amount_after, v_op_account_after, v_op_source_after
  FROM public.operations WHERE id = v_op_id;
  IF v_op_amount_after IS DISTINCT FROM v_op_amount
     OR v_op_account_after IS DISTINCT FROM v_op_account
     OR v_op_source_after IS DISTINCT FROM v_op_source THEN
    RAISE EXCEPTION 'P3-37: operations mutated by P3';
  END IF;

  -- ===== P3-41 same-PAI cannot become Stage F edge =====
  IF NOT public.plaid_internal_transfer_pai_different_proven('pai-same', 'pai-same') THEN
    NULL; -- expected false
  ELSE
    RAISE EXCEPTION 'P3-41: same PAI must fail Stage F PAI predicate';
  END IF;
  IF public.plaid_internal_transfer_pai_different_proven('pai-a', 'pai-b') IS NOT TRUE THEN
    RAISE EXCEPTION 'P3-41: different PAI should pass Stage F predicate';
  END IF;

  -- ===== P3-46..52 regression markers =====
  IF position('backfill' IN lower(v_def_p3)) > 0 THEN
    RAISE EXCEPTION 'P3-46: P4/backfill marker in P3 helper';
  END IF;
  IF position('is_archived' IN lower(v_def_p3)) > 0 THEN
    RAISE EXCEPTION 'P3-35 integrity: must not filter on is_archived';
  END IF;

  -- Ordinary persist metadata still works (P3-50)
  v_synced := public.plaid_persist_accounts_sync(
    v_user_id, v_item_id, 'ins_p3', 'P3 Bank', null, null, null, now(),
    jsonb_build_array(
      jsonb_build_object(
        'plaid_account_id', 'p3-ordinary-meta',
        'name', 'Ordinary',
        'plaid_type', 'depository',
        'plaid_subtype', 'checking',
        'currency_code', 'USD',
        'current_balance', 1,
        'available_balance', 1
      )
    )
  );
  IF v_synced <> 1 THEN
    RAISE EXCEPTION 'P3-50: ordinary persist failed';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.accounts a
    JOIN public.plaid_canonical_financial_account_members m
      ON m.account_id = a.id AND m.unlinked_at IS NULL
    WHERE a.user_id = v_user_id AND a.plaid_account_id = 'p3-ordinary-meta'
      AND m.role = 'authoritative'
  ) THEN
    RAISE EXCEPTION 'P3-50: ordinary account missing singleton after persist';
  END IF;

  -- P1 still callable (P3-51)
  IF position('v_survivor_canonical_id' IN v_def_p1) = 0 THEN
    RAISE EXCEPTION 'P3-51: P1 merge semantics missing';
  END IF;

  -- P2 ensure still created/already_membered (P3-52)
  v_acc_c := pg_temp.make_plaid(v_user_id, v_item_id, 'p3-p2-compat', NULL);
  v_result := public.plaid_ensure_account_identity(v_user_id, v_acc_c);
  IF coalesce(v_result->>'status', '') <> 'created' THEN
    RAISE EXCEPTION 'P3-52: ensure created broken';
  END IF;
  v_result := public.plaid_ensure_account_identity(v_user_id, v_acc_c);
  IF coalesce(v_result->>'status', '') <> 'already_membered' THEN
    RAISE EXCEPTION 'P3-52: ensure already_membered broken';
  END IF;

  -- P3-32: dual-authority prevented by unique + post-check in helper
  IF position('v_distinct_canonicals' IN v_def_p3) = 0 THEN
    RAISE EXCEPTION 'P3-32: post-reconcile single-canonical assertion missing';
  END IF;

  -- H1/H2/Manual untouched structurally: no references in P3 helper to H2 helpers
  IF position('h2' IN lower(v_def_p3)) > 0 THEN
    RAISE EXCEPTION 'P3-48: H2 referenced in P3';
  END IF;

  -- P3-57 / P3-58 lock-key semantics (behavioral + structural):
  -- stored PAI wins via coalesce(existing, incoming); NULL→P uses incoming as effective
  -- before upsert (see P3-22 first-fill + P3-23 first-wins assertions above).
  IF position('coalesce(v_existing_pai, v_persistent_account_id)' IN lower(v_def_persist)) = 0
     AND position('coalesce(v_existing_pai,v_persistent_account_id)' IN lower(v_def_persist)) = 0 THEN
    RAISE EXCEPTION 'P3-57/P3-58: effective PAI coalesce missing for advisory key';
  END IF;

  -- True multi-session concurrency not executed in this single-session harness.

END;
$$;

SELECT 'IDENTITY_P3_VALIDATION_PASS' AS identity_p3_validation_result;

ROLLBACK;
