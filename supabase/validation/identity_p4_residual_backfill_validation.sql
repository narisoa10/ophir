-- =============================================================================
-- Identity P4 validation: residual Plaid account identity backfill capability
-- BEGIN … ROLLBACK. Requires 20260818160000_plaid_residual_identity_backfill.sql
-- PASS via SELECT (not NOTICE).
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_user_id uuid := 'a0b40000-0000-4000-8000-000000000001';
  v_user_other uuid := 'a0b40000-0000-4000-8000-000000000002';
  v_item_id uuid := 'a0b40000-0000-4000-8000-000000000010';
  v_item_b uuid := 'a0b40000-0000-4000-8000-000000000012';
  v_item_other uuid := 'a0b40000-0000-4000-8000-000000000011';
  v_secret_id uuid := 'a0b40000-0000-4000-8000-0000000000ff';
  v_secret_b uuid := 'a0b40000-0000-4000-8000-0000000000fd';
  v_secret_other uuid := 'a0b40000-0000-4000-8000-0000000000fe';
  v_identity_id uuid := 'a0b40000-0000-4000-8000-0000000000aa';
  v_identity_other uuid := 'a0b40000-0000-4000-8000-0000000000ab';

  v_acc_a uuid;
  v_acc_b uuid;
  v_acc_c uuid;
  v_acc_manual uuid;
  v_acc_foreign uuid;
  v_can uuid;
  v_auth uuid;
  v_result jsonb;
  v_result2 jsonb;
  v_op_id uuid;
  v_op_amount numeric;
  v_op_account uuid;
  v_op_source text;
  v_def_p4 text;
  v_def_persist text;
  v_def_ensure text;
  v_def_p3 text;
  v_def_p1 text;
  v_def_f text;
  v_ids uuid[];
  v_cursor uuid;
  v_canons integer;
  v_auth_count integer;
  v_sec_count integer;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id IN (v_user_id, v_user_other)) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: auth.users';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_backfill_account_identity(uuid,integer,uuid)'::regprocedure
  ) INTO v_def_p4;
  SELECT pg_get_functiondef(
    'public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)'::regprocedure
  ) INTO v_def_persist;
  SELECT pg_get_functiondef(
    'public.plaid_ensure_account_identity(uuid,uuid)'::regprocedure
  ) INTO v_def_ensure;
  SELECT pg_get_functiondef(
    'public.plaid_reconcile_account_identity_by_pai(uuid,uuid)'::regprocedure
  ) INTO v_def_p3;
  SELECT pg_get_functiondef(
    'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)'::regprocedure
  ) INTO v_def_p1;

  IF v_def_p4 IS NULL THEN
    RAISE EXCEPTION 'P4: backfill RPC missing';
  END IF;

  -- P4-17 / P4-34 / P4-35 / P4-36 / P4-37 / P4-38
  IF position('plaid_ensure_account_identity' IN v_def_p4) = 0 THEN
    RAISE EXCEPTION 'P4-34: RPC must call P2 ensure';
  END IF;
  IF position('plaid_reconcile_account_identity_by_pai' IN v_def_p4) = 0 THEN
    RAISE EXCEPTION 'P4-35: RPC must call P3 reconcile';
  END IF;
  IF position('insert into public.plaid_canonical_financial_accounts' IN lower(v_def_p4)) > 0 THEN
    RAISE EXCEPTION 'P4-36: backfill must not INSERT canonicals';
  END IF;
  IF position('insert into public.plaid_canonical_financial_account_members' IN lower(v_def_p4)) > 0 THEN
    RAISE EXCEPTION 'P4-37: backfill must not INSERT memberships';
  END IF;
  IF position('plaid_link_canonical_financial_accounts' IN v_def_p4) > 0 THEN
    RAISE EXCEPTION 'P4-38/P4-11: backfill must not call P1 directly';
  END IF;

  -- P4-18 / limit bound
  IF position('v_limit > 100' IN v_def_p4) = 0
     AND position('v_limit > 100' IN lower(v_def_p4)) = 0 THEN
    -- accept either case from pg_get_functiondef
    IF position('> 100' IN v_def_p4) = 0 THEN
      RAISE EXCEPTION 'P4-18: max limit bound missing';
    END IF;
  END IF;

  -- P4-20 ordering
  IF position('order by accounts.id' IN lower(v_def_p4)) = 0 THEN
    RAISE EXCEPTION 'P4-20: deterministic per-user order missing';
  END IF;

  -- P4-30..33: capability only — persist must not auto-invoke backfill
  IF position('plaid_backfill_account_identity' IN v_def_persist) > 0 THEN
    RAISE EXCEPTION 'P4-30: persist must not auto-call backfill';
  END IF;
  IF position('plaid_backfill_account_identity' IN v_def_ensure) > 0
     OR position('plaid_backfill_account_identity' IN v_def_p3) > 0 THEN
    RAISE EXCEPTION 'P4-31: P2/P3 must not call backfill';
  END IF;

  -- P4-40..45 structural
  IF position('plaid_resolve_duplicate_operations' IN v_def_p4) > 0
     OR position('stage_e' IN lower(v_def_p4)) > 0 THEN
    RAISE EXCEPTION 'P4-41: Stage E must not be invoked';
  END IF;
  IF position('materialize' IN lower(v_def_p4)) > 0 THEN
    RAISE EXCEPTION 'P4-40: Stage D must not be invoked';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)'::regprocedure
  ) INTO v_def_f;
  IF position('stage_f_v2' IN v_def_f) = 0 THEN
    RAISE EXCEPTION 'P4-42: Stage F v2 body not present';
  END IF;
  IF position('plaid_backfill_account_identity' IN v_def_f) > 0 THEN
    RAISE EXCEPTION 'P4-42: Stage F must not call backfill';
  END IF;

  IF position('plaid_reconcile_confirmed_internal_transfers_for_user' IN v_def_p1) = 0 THEN
    RAISE EXCEPTION 'P4-43: Stage G hook missing from P1';
  END IF;

  IF NOT has_function_privilege(
    'service_role',
    'public.plaid_backfill_account_identity(uuid,integer,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P4: service_role missing EXECUTE';
  END IF;
  IF has_function_privilege(
    'authenticated',
    'public.plaid_backfill_account_identity(uuid,integer,uuid)',
    'EXECUTE'
  ) OR has_function_privilege(
    'anon',
    'public.plaid_backfill_account_identity(uuid,integer,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P4: anon/authenticated must not EXECUTE backfill';
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
      'identity-p4-' || v_user_id::text || '@ophir.invalid',
      extensions.crypt('identity-p4-not-used', extensions.gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      now(), now(), '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000', v_user_other,
      'authenticated', 'authenticated',
      'identity-p4-' || v_user_other::text || '@ophir.invalid',
      extensions.crypt('identity-p4-not-used', extensions.gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      now(), now(), '', '', '', ''
    );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) VALUES
    (
      v_identity_id, v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', 'identity-p4-' || v_user_id::text || '@ophir.invalid'),
      'email', v_user_id::text, now(), now(), now()
    ),
    (
      v_identity_other, v_user_other,
      jsonb_build_object('sub', v_user_other::text, 'email', 'identity-p4-' || v_user_other::text || '@ophir.invalid'),
      'email', v_user_other::text, now(), now(), now()
    );

  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id)
     OR NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_other) THEN
    RAISE EXCEPTION 'FIXTURE: profile missing';
  END IF;

  INSERT INTO public.plaid_items (
    id, user_id, plaid_environment, plaid_item_id, access_token_secret_id
  ) VALUES
    (v_item_id, v_user_id, 'sandbox', 'identity-p4-item-a-' || v_user_id::text, v_secret_id),
    (v_item_b, v_user_id, 'sandbox', 'identity-p4-item-b-' || v_user_id::text, v_secret_b),
    (v_item_other, v_user_other, 'sandbox', 'identity-p4-item-' || v_user_other::text, v_secret_other);

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
      v_id, p_user_id, 'P4 ' || p_plaid_account_id, 'bank', 'USD',
      0, 'bank', 'blue', 0, p_archived,
      p_item_id, p_plaid_account_id, 'depository', 'checking',
      p_pai
    );
    RETURN v_id;
  END;
  $fn$;

  -- ===== P4-1..P4-4 unmembered + null PAI =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p4-core-null', NULL);
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P4-1 setup: unexpected membership';
  END IF;

  v_result := public.plaid_backfill_account_identity(v_user_id, 50, NULL);
  IF coalesce((v_result->>'processed')::int, -1) < 1 THEN
    RAISE EXCEPTION 'P4-1: processed expected >=1, got %', v_result;
  END IF;
  IF coalesce((v_result->>'ensure_created')::int, 0) < 1 THEN
    RAISE EXCEPTION 'P4-49: ensure_created expected, got %', v_result;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL AND m.role = 'authoritative'
      AND m.link_origin = 'sync_bootstrap'
  ) THEN
    RAISE EXCEPTION 'P4-1/P4-2/P4-3: membership/auth/sync_bootstrap missing';
  END IF;
  IF coalesce(v_result->>'not_applicable', '') = '0'
     AND (
       SELECT a.persistent_account_id FROM public.accounts a WHERE a.id = v_acc_a
     ) IS NULL THEN
    -- null PAI account should contribute not_applicable on reconcile
    NULL;
  END IF;
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P4-4: null PAI should remain singleton';
  END IF;

  -- ===== P4-5 / P4-6 already-correct =====
  v_result2 := public.plaid_backfill_account_identity(v_user_id, 50, NULL);
  IF coalesce((v_result2->>'ensure_already_membered')::int, 0) < 1 THEN
    RAISE EXCEPTION 'P4-5/P4-50: expected already_membered on rerun %', v_result2;
  END IF;
  IF coalesce((v_result2->>'ensure_created')::int, 0) <> 0 THEN
    RAISE EXCEPTION 'P4-5: rerun created new identity';
  END IF;

  -- secondary must not be promoted
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p4-sec-host', NULL);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  SELECT m.canonical_account_id INTO v_can
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL;
  v_acc_c := pg_temp.make_plaid(v_user_id, v_item_id, 'p4-sec-child', NULL);
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin
  ) VALUES (
    v_user_id, v_can, v_acc_c, 'secondary', 'user_confirmed'
  );
  v_result := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF (
    SELECT m.role FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_c AND m.unlinked_at IS NULL
  ) IS DISTINCT FROM 'secondary' THEN
    RAISE EXCEPTION 'P4-6: secondary promoted';
  END IF;

  -- ===== P4-7..P4-11 same PAI =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p4-pai-a', 'pai-p4-two');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p4-pai-b', 'pai-p4-two');
  -- leave unmembered; backfill ensure+reconcile
  v_result := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P4-7: same-PAI pair not converged';
  END IF;
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
      AND m.role = 'authoritative'
  ) <> 1 THEN
    RAISE EXCEPTION 'P4-7: expected one authority';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b)
      AND m.unlinked_at IS NULL
      AND m.role = 'secondary'
      AND m.link_origin = 'persistent_account_identity'
  ) THEN
    RAISE EXCEPTION 'P4-10: merge evidence missing';
  END IF;

  -- three siblings
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p4-tri-a', 'pai-p4-tri');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p4-tri-b', 'pai-p4-tri');
  v_acc_c := pg_temp.make_plaid(v_user_id, v_item_id, 'p4-tri-c', 'pai-p4-tri');
  v_result := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  SELECT
    count(DISTINCT m.canonical_account_id)::int,
    count(*) FILTER (WHERE m.role = 'authoritative')::int,
    count(*) FILTER (WHERE m.role = 'secondary')::int
  INTO v_canons, v_auth_count, v_sec_count
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b, v_acc_c) AND m.unlinked_at IS NULL;
  IF v_canons <> 1 OR v_auth_count <> 1 OR v_sec_count <> 2 THEN
    RAISE EXCEPTION 'P4-8: tri topology canons=% auth=% sec=%',
      v_canons, v_auth_count, v_sec_count;
  END IF;

  -- ===== P4-12 different PAI =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p4-diff-a', 'pai-diff-a');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p4-diff-b', 'pai-diff-b');
  v_result := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'P4-12: different PAI merged';
  END IF;

  -- ===== P4-13 Manual excluded =====
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P4 Manual', 'cash', 'USD',
    0, 'cash', 'green', 0, false
  ) RETURNING id INTO v_acc_manual;
  v_result := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_manual AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P4-13: Manual gained membership';
  END IF;

  -- ===== P4-14 foreign user =====
  v_acc_foreign := pg_temp.make_plaid(v_user_other, v_item_other, 'p4-foreign', NULL);
  v_result := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_foreign AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P4-14/P4-21: foreign account processed by other user batch';
  END IF;

  -- ===== P4-15 archived included =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p4-arch', NULL, true);
  v_result := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P4-15: archived excluded';
  END IF;

  -- ===== P4-17..P4-25 batching / cursor (dedicated user = clean id space) =====
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived,
    plaid_item_id, plaid_account_id, plaid_type, plaid_subtype
  ) VALUES
    ('a0b40000-0000-4000-8000-0000000000b1', v_user_other, 'P4 Page1', 'bank', 'USD',
     0, 'bank', 'blue', 0, false, v_item_other, 'p4-page-1', 'depository', 'checking'),
    ('a0b40000-0000-4000-8000-0000000000b2', v_user_other, 'P4 Page2', 'bank', 'USD',
     0, 'bank', 'blue', 0, false, v_item_other, 'p4-page-2', 'depository', 'checking'),
    ('a0b40000-0000-4000-8000-0000000000b3', v_user_other, 'P4 Page3', 'bank', 'USD',
     0, 'bank', 'blue', 0, false, v_item_other, 'p4-page-3', 'depository', 'checking');

  -- Foreign unmembered leftover from P4-14 may sort before/after; delete non-page foreign rows.
  DELETE FROM public.plaid_canonical_financial_account_members
  WHERE user_id = v_user_other;
  DELETE FROM public.accounts
  WHERE user_id = v_user_other
    AND plaid_account_id IS DISTINCT FROM 'p4-page-1'
    AND plaid_account_id IS DISTINCT FROM 'p4-page-2'
    AND plaid_account_id IS DISTINCT FROM 'p4-page-3';

  v_result := public.plaid_backfill_account_identity(v_user_other, 1, NULL);
  IF coalesce((v_result->>'processed')::int, -1) <> 1 THEN
    RAISE EXCEPTION 'P4-18: limit=1 processed=%', v_result;
  END IF;
  v_cursor := (v_result->>'next_after_account_id')::uuid;
  IF v_cursor IS DISTINCT FROM 'a0b40000-0000-4000-8000-0000000000b1'::uuid THEN
    RAISE EXCEPTION 'P4-22: unexpected cursor %', v_cursor;
  END IF;
  IF coalesce((v_result->>'has_more')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'P4-23: has_more should be true';
  END IF;

  v_result2 := public.plaid_backfill_account_identity(v_user_other, 1, v_cursor);
  IF coalesce((v_result2->>'processed')::int, -1) <> 1 THEN
    RAISE EXCEPTION 'P4-24: second batch processed=%', v_result2;
  END IF;
  IF (v_result2->>'next_after_account_id')::uuid
     IS DISTINCT FROM 'a0b40000-0000-4000-8000-0000000000b2'::uuid THEN
    RAISE EXCEPTION 'P4-24: second cursor wrong %', v_result2;
  END IF;

  -- ===== P4-25 idempotent full rerun (primary user) =====
  v_result := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  v_result2 := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF coalesce((v_result2->>'ensure_created')::int, -1) <> 0 THEN
    RAISE EXCEPTION 'P4-25: second full run created identities %', v_result2;
  END IF;

  -- ===== P4-26 / P4-27 invalid inputs =====
  BEGIN
    PERFORM public.plaid_backfill_account_identity(NULL, 10, NULL);
    RAISE EXCEPTION 'P4-27: expected invalid_input for null user';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT ILIKE '%invalid_input%' THEN
      RAISE EXCEPTION 'P4-27: unexpected %', SQLERRM;
    END IF;
  END;

  BEGIN
    PERFORM public.plaid_backfill_account_identity(v_user_id, 0, NULL);
    RAISE EXCEPTION 'P4-26: expected invalid_input for limit 0';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT ILIKE '%invalid_input%' THEN
      RAISE EXCEPTION 'P4-26: unexpected %', SQLERRM;
    END IF;
  END;

  BEGIN
    PERFORM public.plaid_backfill_account_identity(v_user_id, 101, NULL);
    RAISE EXCEPTION 'P4-26: expected invalid_input for limit 101';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT ILIKE '%invalid_input%' THEN
      RAISE EXCEPTION 'P4-26: unexpected %', SQLERRM;
    END IF;
  END;

  -- ===== P4-28: no failed counter in result =====
  IF v_def_p4 ILIKE '%failed%' AND position('''failed''' IN v_def_p4) > 0 THEN
    RAISE EXCEPTION 'P4-28: failed count must not be accumulated';
  END IF;

  -- ===== P4-39 operations unchanged =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p4-op-a', NULL);
  v_op_id := gen_random_uuid();
  INSERT INTO public.operations (
    id, user_id, from_account_id, to_account_id, type, amount,
    currency_code, occurred_at, source, category_id, archived_at,
    category_overridden, recurrence, is_recurring
  ) VALUES (
    v_op_id, v_user_id, v_acc_a, null, 'expense', 9.99,
    'USD', DATE '2026-08-01', 'plaid', null, null,
    false, 'none', false
  );
  SELECT amount, from_account_id, source
  INTO v_op_amount, v_op_account, v_op_source
  FROM public.operations WHERE id = v_op_id;
  PERFORM public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF (
    SELECT amount FROM public.operations WHERE id = v_op_id
  ) IS DISTINCT FROM v_op_amount
     OR (
    SELECT from_account_id FROM public.operations WHERE id = v_op_id
  ) IS DISTINCT FROM v_op_account
     OR (
    SELECT source FROM public.operations WHERE id = v_op_id
  ) IS DISTINCT FROM v_op_source THEN
    RAISE EXCEPTION 'P4-39: operations mutated';
  END IF;

  -- ===== P4-47 P1/P2/P3 presence =====
  IF position('v_survivor_canonical_id' IN v_def_p1) = 0 THEN
    RAISE EXCEPTION 'P4-47: P1 merge missing';
  END IF;
  IF position('already_membered' IN v_def_ensure) = 0 THEN
    RAISE EXCEPTION 'P4-47: P2 ensure missing';
  END IF;
  IF position('plaid_lock_account_identity_pai_group' IN v_def_p3) = 0 THEN
    RAISE EXCEPTION 'P4-47: P3 reconcile missing';
  END IF;

  -- P4-16 structural: no Item health filter in backfill
  IF position('needs_reauth' IN lower(v_def_p4)) > 0
     OR position('connection' IN lower(v_def_p4)) > 0 THEN
    RAISE EXCEPTION 'P4-16: Item health used as identity criterion';
  END IF;
  IF position('is_archived' IN lower(v_def_p4)) > 0 THEN
    RAISE EXCEPTION 'P4-15 integrity: must not filter is_archived';
  END IF;

END;
$$;

SELECT 'IDENTITY_P4_VALIDATION_PASS' AS identity_p4_validation_result;

ROLLBACK;
