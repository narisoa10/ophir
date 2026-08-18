-- =============================================================================
-- Identity P5: final identity foundation validation / regression closeout
--
-- Validation-only. No production migration. No LIVE mutation.
-- High-value CROSS-LAYER integration of P1–P4 + Stage D/E/F/G compatibility.
-- Individual P1–P4 harnesses remain separate evidence; this file does not
-- duplicate them wholesale.
--
-- External LIVE read-only final gate (operator, after this harness PASS):
--   1. unmembered Plaid = 0
--   2. canonical with active members and no authority = 0
--   3. multi-authority canonical = 0
--   4. duplicate active membership = 0
--   5. same-PAI split canonical groups = 0
--   6. same-PAI multi-authority groups = 0
--   7. Manual sync_bootstrap = 0
--   8. link_origin distribution — informational
--   9. orphan empty canonical count — informational / report-only
--  10. IT reconciliation count — informational
--  11. historical unlinked memberships — informational
--
-- PASS via SELECT (not NOTICE). BEGIN … ROLLBACK.
-- Requires P1–P4 + Stage F hardening applied.
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_user_id uuid := 'a0b50000-0000-4000-8000-000000000001';
  v_item_id uuid := 'a0b50000-0000-4000-8000-000000000010';
  v_item_b uuid := 'a0b50000-0000-4000-8000-000000000012';
  v_secret_id uuid := 'a0b50000-0000-4000-8000-0000000000ff';
  v_secret_b uuid := 'a0b50000-0000-4000-8000-0000000000fd';
  v_identity_id uuid := 'a0b50000-0000-4000-8000-0000000000aa';

  v_acc_a uuid;
  v_acc_b uuid;
  v_acc_c uuid;
  v_acc_manual uuid;
  v_can_a uuid;
  v_can_lose uuid;
  v_auth uuid;
  v_result jsonb;
  v_result2 jsonb;
  v_op_id uuid;
  v_op_amount numeric;
  v_op_account uuid;
  v_op_source text;
  v_op_archived timestamptz;

  v_def_p1 text;
  v_def_p2 text;
  v_def_p3 text;
  v_def_p4 text;
  v_def_lock text;
  v_def_persist text;
  v_def_stage_d_mat text;
  v_def_stage_f text;
  v_def_p3_nocomment text;
  v_def_persist_nocomment text;
  v_pos_lock integer;
  v_pos_for_update integer;
  v_pos_upsert integer;
  v_fn text;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id = v_user_id) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: auth.users';
  END IF;

  -- ----- Structural indexes / uniqueness (P5-17 / P5-18 / P5-36) -----
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_canonical_financial_account_members_active_account_uidx'
  ) THEN
    RAISE EXCEPTION 'P5-17: active membership unique missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_canonical_financial_account_members_active_authority_uidx'
  ) THEN
    RAISE EXCEPTION 'P5-18: active authority unique missing';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)'::regprocedure
  ) INTO v_def_p1;
  SELECT pg_get_functiondef(
    'public.plaid_ensure_account_identity(uuid,uuid)'::regprocedure
  ) INTO v_def_p2;
  SELECT pg_get_functiondef(
    'public.plaid_reconcile_account_identity_by_pai(uuid,uuid)'::regprocedure
  ) INTO v_def_p3;
  SELECT pg_get_functiondef(
    'public.plaid_backfill_account_identity(uuid,integer,uuid)'::regprocedure
  ) INTO v_def_p4;
  SELECT pg_get_functiondef(
    'public.plaid_lock_account_identity_pai_group(uuid,text)'::regprocedure
  ) INTO v_def_lock;
  SELECT pg_get_functiondef(
    'public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)'::regprocedure
  ) INTO v_def_persist;
  SELECT pg_get_functiondef(p.oid)
  INTO v_def_stage_d_mat
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'plaid_materialize_transaction_operations'
  ORDER BY p.oid
  LIMIT 1;
  SELECT pg_get_functiondef(
    'public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)'::regprocedure
  ) INTO v_def_stage_f;

  IF v_def_p1 IS NULL OR v_def_p2 IS NULL OR v_def_p3 IS NULL OR v_def_p4 IS NULL THEN
    RAISE EXCEPTION 'P5: missing P1–P4 helpers';
  END IF;

  -- P5-30 persist signature
  IF to_regprocedure(
    'public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)'
  ) IS NULL THEN
    RAISE EXCEPTION 'P5-30: persist signature changed';
  END IF;

  -- P5-29 security / grants
  FOREACH v_fn IN ARRAY ARRAY[
    'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)',
    'public.plaid_ensure_account_identity(uuid,uuid)',
    'public.plaid_lock_account_identity_pai_group(uuid,text)',
    'public.plaid_reconcile_account_identity_by_pai(uuid,uuid)',
    'public.plaid_backfill_account_identity(uuid,integer,uuid)'
  ]
  LOOP
    IF NOT has_function_privilege('service_role', v_fn::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'P5-29: service_role missing EXECUTE on %', v_fn;
    END IF;
    IF has_function_privilege('authenticated', v_fn::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'P5-29: authenticated must not EXECUTE %', v_fn;
    END IF;
    IF has_function_privilege('anon', v_fn::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'P5-29: anon must not EXECUTE %', v_fn;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'plaid_ensure_account_identity'
      AND p.prosecdef
  ) THEN
    RAISE EXCEPTION 'P5-29: ensure must be SECURITY DEFINER';
  END IF;

  -- P5-21 / P5-45 Stage E not invoked by identity helpers
  IF position('plaid_resolve_duplicate_operations' IN v_def_p2) > 0
     OR position('plaid_resolve_duplicate_operations' IN v_def_p3) > 0
     OR position('plaid_resolve_duplicate_operations' IN v_def_p4) > 0 THEN
    RAISE EXCEPTION 'P5-21: Stage E invoked from identity helpers';
  END IF;

  -- P5-27 no auto-confirm
  IF position('plaid_confirm_internal_transfer_candidate' IN v_def_p2) > 0
     OR position('plaid_confirm_internal_transfer_candidate' IN v_def_p3) > 0
     OR position('plaid_confirm_internal_transfer_candidate' IN v_def_p4) > 0
     OR position('plaid_confirm_internal_transfer_candidate' IN v_def_p1) > 0 THEN
    RAISE EXCEPTION 'P5-27: identity layer must not auto-confirm IT';
  END IF;

  -- P5-26 Stage G hook on P1
  IF position(
    'plaid_reconcile_confirmed_internal_transfers_for_user' IN v_def_p1
  ) = 0 THEN
    RAISE EXCEPTION 'P5-26: P1 missing Stage G consistency hook';
  END IF;

  -- P5-19 / P5-20 Stage D structural
  IF v_def_stage_d_mat IS NULL
     OR (
       position('canonical_secondary' IN v_def_stage_d_mat) = 0
       AND position('secondary' IN lower(v_def_stage_d_mat)) = 0
     ) THEN
    RAISE EXCEPTION 'P5-19/P5-20: Stage D secondary suppression semantics missing';
  END IF;

  -- P5-23/24/25 Stage F v2 present + not PAI-only in detector
  IF position('stage_f_v2' IN v_def_stage_f) = 0 THEN
    RAISE EXCEPTION 'P5-23: Stage F v2 body missing';
  END IF;
  IF position('plaid_internal_transfer_pfc_directional_compatible' IN v_def_stage_f) = 0 THEN
    RAISE EXCEPTION 'P5-25: Stage F must still require directional PFC beyond PAI';
  END IF;

  -- P5-31 P3 lock order (comment-stripped)
  v_def_p3_nocomment := regexp_replace(lower(v_def_p3), '--[^\n]*', '', 'g');
  v_pos_lock := position(
    'plaid_lock_account_identity_pai_group' IN v_def_p3_nocomment
  );
  v_pos_for_update := position('for update' IN v_def_p3_nocomment);
  IF v_pos_lock = 0 OR v_pos_for_update = 0 OR v_pos_lock > v_pos_for_update THEN
    RAISE EXCEPTION 'P5-31: P3 advisory must precede executable FOR UPDATE';
  END IF;

  v_def_persist_nocomment := regexp_replace(lower(v_def_persist), '--[^\n]*', '', 'g');
  v_pos_lock := position(
    'plaid_lock_account_identity_pai_group' IN v_def_persist_nocomment
  );
  v_pos_upsert := position('insert into public.accounts' IN v_def_persist_nocomment);
  IF v_pos_lock = 0 OR v_pos_upsert = 0 OR v_pos_lock > v_pos_upsert THEN
    RAISE EXCEPTION 'P5-31: persist PAI advisory must precede account upsert';
  END IF;

  -- P5-32 / P5-42: no auto-backfill wiring into persist; ownership separation
  IF position('plaid_backfill_account_identity' IN v_def_persist) > 0 THEN
    RAISE EXCEPTION 'P5-32: persist must not auto-call P4 backfill';
  END IF;
  IF position('plaid_link_canonical_financial_accounts' IN v_def_p4) > 0 THEN
    RAISE EXCEPTION 'P5-42: P4 must not call P1 directly';
  END IF;
  IF position('plaid_ensure_account_identity' IN v_def_p4) = 0
     OR position('plaid_reconcile_account_identity_by_pai' IN v_def_p4) = 0 THEN
    RAISE EXCEPTION 'P5-42: P4 must orchestrate P2 then P3';
  END IF;

  -- P5-43 P4 per-user fencing structural
  IF position('accounts.user_id = p_user_id' IN lower(v_def_p4)) = 0 THEN
    RAISE EXCEPTION 'P5-43: P4 missing per-user fencing';
  END IF;

  -- P5-38 narrow: identity helpers do not DELETE/UPDATE operations themselves
  IF position('delete from public.operations' IN lower(v_def_p2)) > 0
     OR position('delete from public.operations' IN lower(v_def_p3)) > 0
     OR position('delete from public.operations' IN lower(v_def_p4)) > 0 THEN
    RAISE EXCEPTION 'P5-38: identity helpers must not delete operations';
  END IF;

  -- Auth fixtures
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000', v_user_id,
    'authenticated', 'authenticated',
    'identity-p5-' || v_user_id::text || '@ophir.invalid',
    extensions.crypt('identity-p5-not-used', extensions.gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_identity_id, v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', 'identity-p5-' || v_user_id::text || '@ophir.invalid'),
    'email', v_user_id::text, now(), now(), now()
  );

  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id) THEN
    RAISE EXCEPTION 'FIXTURE: profile missing';
  END IF;

  INSERT INTO public.plaid_items (
    id, user_id, plaid_environment, plaid_item_id, access_token_secret_id
  ) VALUES
    (v_item_id, v_user_id, 'sandbox', 'identity-p5-item-a', v_secret_id),
    (v_item_b, v_user_id, 'sandbox', 'identity-p5-item-b', v_secret_b);

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
      v_id, p_user_id, 'P5 ' || p_plaid_account_id, 'bank', 'USD',
      0, 'bank', 'blue', 0, p_archived,
      p_item_id, p_plaid_account_id, 'depository', 'checking',
      p_pai
    );
    RETURN v_id;
  END;
  $fn$;

  -- ===== P5-1 / P5-2 / P5-9 / P5-14 P2 singleton =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p5-single', NULL);
  v_result := public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'created' THEN
    RAISE EXCEPTION 'P5-1: expected created %', v_result;
  END IF;
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P5-1: expected exactly one active membership';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL
      AND m.role = 'authoritative' AND m.link_origin = 'sync_bootstrap'
  ) THEN
    RAISE EXCEPTION 'P5-2/P5-9: authoritative sync_bootstrap missing';
  END IF;
  SELECT m.canonical_account_id INTO v_can_a
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL;
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_account_members m
    WHERE m.canonical_account_id = v_can_a AND m.unlinked_at IS NULL
      AND m.role = 'authoritative'
  ) <> 1 THEN
    RAISE EXCEPTION 'P5-2: canonical authority count != 1';
  END IF;

  v_result2 := public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  IF coalesce(v_result2->>'status', '') <> 'already_membered' THEN
    RAISE EXCEPTION 'P5-14: expected already_membered';
  END IF;
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_accounts c
    WHERE c.user_id = v_user_id
  ) < 1 THEN
    RAISE EXCEPTION 'P5-14 setup anomaly';
  END IF;

  -- ===== P5-3 / P5-39 Manual isolation =====
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P5 Manual', 'cash', 'USD',
    0, 'cash', 'green', 0, false
  ) RETURNING id INTO v_acc_manual;
  BEGIN
    PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_manual);
    RAISE EXCEPTION 'P5-3: Manual must not bootstrap';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT ILIKE '%account_not_plaid%' THEN
      RAISE EXCEPTION 'P5-3: unexpected %', SQLERRM;
    END IF;
  END;
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_manual AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P5-3/P5-39: Manual membership created';
  END IF;

  -- ===== P5-4 null PAI: ensure + P3 no merge =====
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p5-null-b', NULL);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'not_applicable' THEN
    RAISE EXCEPTION 'P5-4: null PAI expected not_applicable, got %', v_result;
  END IF;
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'P5-4: null PAI accounts merged';
  END IF;

  -- ===== P5-11 user_confirmed preserved by ensure =====
  UPDATE public.plaid_canonical_financial_account_members
  SET link_origin = 'user_confirmed'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  IF (
    SELECT m.link_origin FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL
  ) IS DISTINCT FROM 'user_confirmed' THEN
    RAISE EXCEPTION 'P5-11: user_confirmed rewritten by ensure';
  END IF;

  -- ===== P5-12 historical membership =====
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin,
    linked_at, unlinked_at
  ) VALUES (
    v_user_id, v_can_a, v_acc_a, 'secondary', 'user_confirmed',
    timestamptz '2024-01-01 00:00:00+00',
    timestamptz '2024-06-01 00:00:00+00'
  );
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P5-12: historical counted as active';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'P5-12: historical row missing';
  END IF;

  -- ===== P5-5 / P5-8 / P5-10 / P5-15 same PAI pair + AUTH_A =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p5-pai-a', 'pai-p5-pair');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p5-pai-b', 'pai-p5-pair');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2020-01-01 00:00:00+00'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2021-01-01 00:00:00+00'
  WHERE account_id = v_acc_b AND unlinked_at IS NULL;

  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_b);
  IF coalesce(v_result->>'status', '') <> 'reconciled' THEN
    RAISE EXCEPTION 'P5-5: expected reconciled %', v_result;
  END IF;
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P5-5: pair not one canonical';
  END IF;
  SELECT m.account_id INTO v_auth
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b)
    AND m.unlinked_at IS NULL AND m.role = 'authoritative';
  IF v_auth IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P5-8: AUTH_A stolen; want A got %', v_auth;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL
      AND m.role = 'secondary'
      AND m.link_origin = 'persistent_account_identity'
  ) THEN
    RAISE EXCEPTION 'P5-10: persistent_account_identity evidence missing';
  END IF;

  v_result2 := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result2->>'status', '') <> 'already_reconciled' THEN
    RAISE EXCEPTION 'P5-15: expected already_reconciled %', v_result2;
  END IF;
  SELECT m.account_id INTO v_auth
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id IN (v_acc_a, v_acc_b)
    AND m.unlinked_at IS NULL AND m.role = 'authoritative';
  IF v_auth IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P5-15: authority flipped on repeat';
  END IF;

  -- ===== P5-6 three siblings =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p5-tri-a', 'pai-p5-tri');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p5-tri-b', 'pai-p5-tri');
  v_acc_c := pg_temp.make_plaid(v_user_id, v_item_id, 'p5-tri-c', 'pai-p5-tri');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_c);
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2019-01-01 00:00:00+00'
  WHERE account_id = v_acc_a AND unlinked_at IS NULL;
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2019-02-01 00:00:00+00'
  WHERE account_id = v_acc_b AND unlinked_at IS NULL;
  UPDATE public.plaid_canonical_financial_account_members
  SET linked_at = timestamptz '2019-03-01 00:00:00+00'
  WHERE account_id = v_acc_c AND unlinked_at IS NULL;
  PERFORM public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_c);
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b, v_acc_c) AND m.unlinked_at IS NULL
  ) <> 1
     OR (
    SELECT count(*) FILTER (WHERE m.role = 'authoritative')
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b, v_acc_c) AND m.unlinked_at IS NULL
  ) <> 1
     OR (
    SELECT count(*) FILTER (WHERE m.role = 'secondary')
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b, v_acc_c) AND m.unlinked_at IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'P5-6: tri topology invalid';
  END IF;

  -- ===== P5-7 different PAI =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p5-diff-a', 'pai-diff-1');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p5-diff-b', 'pai-diff-2');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  v_result := public.plaid_reconcile_account_identity_by_pai(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'already_reconciled' THEN
    RAISE EXCEPTION 'P5-7: unexpected %', v_result;
  END IF;
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'P5-7: different PAI merged';
  END IF;

  -- ===== P5-13 P1 already_linked idempotency =====
  SELECT m.canonical_account_id INTO v_can_a
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL;
  -- Make B same PAI and merge first via P1 with authority A after setting same PAI
  -- Use dedicated pair already merged above (pai pair). Re-link that pair:
  SELECT a.id INTO v_acc_a
  FROM public.accounts a
  WHERE a.user_id = v_user_id AND a.plaid_account_id = 'p5-pai-a';
  SELECT a.id INTO v_acc_b
  FROM public.accounts a
  WHERE a.user_id = v_user_id AND a.plaid_account_id = 'p5-pai-b';
  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc_a, v_acc_b, v_acc_a
  );
  IF coalesce(v_result->>'status', '') <> 'already_linked' THEN
    RAISE EXCEPTION 'P5-13: expected already_linked got %', v_result;
  END IF;

  -- ===== P5-35 / P5-41 orphan canonical after P1 merge =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p5-orph-a', 'pai-p5-orph');
  v_acc_b := pg_temp.make_plaid(v_user_id, v_item_b, 'p5-orph-b', 'pai-p5-orph');
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  SELECT m.canonical_account_id INTO v_can_a
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL;
  SELECT m.canonical_account_id INTO v_can_lose
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL;
  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc_a, v_acc_b, v_acc_a
  );
  IF coalesce(v_result->>'status', '') <> 'merged' THEN
    RAISE EXCEPTION 'P5-35 setup merge failed %', v_result;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_accounts c WHERE c.id = v_can_lose
  ) THEN
    RAISE EXCEPTION 'P5-35: losing canonical row deleted';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.canonical_account_id = v_can_lose AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P5-35: losing canonical still has active members';
  END IF;
  -- Empty orphan is NOT a P5 failure (report-only policy).

  -- ===== P5-33 archived =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p5-arch', NULL, true);
  v_result := public.plaid_ensure_account_identity(v_user_id, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'created' THEN
    RAISE EXCEPTION 'P5-33: archived ensure failed %', v_result;
  END IF;

  -- ===== P5-16 / P5-22 / P5-44 P4 batch idempotency + ops + no H2 confirm =====
  v_acc_a := pg_temp.make_plaid(v_user_id, v_item_id, 'p5-p4-a', NULL);
  v_op_id := gen_random_uuid();
  INSERT INTO public.operations (
    id, user_id, from_account_id, to_account_id, type, amount,
    currency_code, occurred_at, source, category_id, archived_at,
    category_overridden, recurrence, is_recurring
  ) VALUES (
    v_op_id, v_user_id, v_acc_a, null, 'expense', 7.77,
    'USD', DATE '2026-08-01', 'plaid', null, null,
    false, 'none', false
  );
  SELECT amount, from_account_id, source, archived_at
  INTO v_op_amount, v_op_account, v_op_source, v_op_archived
  FROM public.operations WHERE id = v_op_id;

  v_result := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF coalesce((v_result->>'processed')::int, 0) < 1 THEN
    RAISE EXCEPTION 'P5-16: backfill processed=%', v_result;
  END IF;
  v_result2 := public.plaid_backfill_account_identity(v_user_id, 100, NULL);
  IF coalesce((v_result2->>'ensure_created')::int, -1) <> 0 THEN
    RAISE EXCEPTION 'P5-16: second backfill created identities %', v_result2;
  END IF;
  IF (
    SELECT amount FROM public.operations WHERE id = v_op_id
  ) IS DISTINCT FROM v_op_amount
     OR (
    SELECT from_account_id FROM public.operations WHERE id = v_op_id
  ) IS DISTINCT FROM v_op_account
     OR (
    SELECT source FROM public.operations WHERE id = v_op_id
  ) IS DISTINCT FROM v_op_source
     OR (
    SELECT archived_at FROM public.operations WHERE id = v_op_id
  ) IS DISTINCT FROM v_op_archived THEN
    RAISE EXCEPTION 'P5-22: operations mutated by identity actions';
  END IF;

  -- P5-44: same-PAI path above used P3 without confirm helper — already covered by P5-27.

  -- ===== P5-23 / P5-24 / P5-25 Stage F PAI helper =====
  IF public.plaid_internal_transfer_pai_different_proven('same', 'same') THEN
    RAISE EXCEPTION 'P5-23: same PAI must be false';
  END IF;
  IF public.plaid_internal_transfer_pai_different_proven(NULL, 'x')
     OR public.plaid_internal_transfer_pai_different_proven('x', NULL)
     OR public.plaid_internal_transfer_pai_different_proven(NULL, NULL) THEN
    RAISE EXCEPTION 'P5-24: null PAI must be false';
  END IF;
  IF NOT public.plaid_internal_transfer_pai_different_proven('a', 'b') THEN
    RAISE EXCEPTION 'P5-25: different PAI identity proof should be true';
  END IF;
  -- Candidate still requires PFC (structural already asserted on Stage F body).

  -- Manual still untouched
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_manual AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P5-39: Manual mutated later';
  END IF;

END;
$$;

SELECT 'IDENTITY_P5_VALIDATION_PASS' AS identity_p5_validation_result;

ROLLBACK;
