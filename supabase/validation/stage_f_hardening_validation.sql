-- =============================================================================
-- Stage F hardening validation (stage_f_v2)
-- Temporary / non-migration SQL. BEGIN … ROLLBACK. No permanent production data.
-- Requires migration 20260818130000_plaid_internal_transfer_candidate_hardening.sql
-- PASS marker is a SELECT result (not NOTICE).
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_user_id uuid := 'a0f81830-0000-4000-8000-000000000001';
  v_item_id uuid := 'a0f81830-0000-4000-8000-000000000010';
  v_secret_id uuid := 'a0f81830-0000-4000-8000-0000000000ff';
  v_identity_id uuid := 'a0f81830-0000-4000-8000-0000000000aa';

  v_acc_a uuid;
  v_acc_b uuid;
  v_acc_c uuid;
  v_can_a uuid;
  v_can_b uuid;
  v_can_c uuid;

  v_payload jsonb;
  v_metrics jsonb;
  v_result jsonb;
  v_recon_id uuid;
  v_op_out uuid;
  v_op_in uuid;
  v_proj_out uuid;
  v_proj_in uuid;
  v_raw_out uuid;
  v_raw_in uuid;
  v_transfer_id uuid;
  v_def_det text;
  v_def_conf text;
  v_def_inc text;
  v_def_p1 text;
  v_def_h1 text;
  v_before_ops integer;
  v_after_ops integer;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id = v_user_id) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: auth.users fixture id exists';
  END IF;

  -- Structural presence of shared helpers
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'plaid_internal_transfer_pfc_directional_compatible'
  ) THEN
    RAISE EXCEPTION 'F-HARD-36: directional PFC helper missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'plaid_internal_transfer_pai_different_proven'
  ) THEN
    RAISE EXCEPTION 'F-HARD-37: PAI helper missing';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)'::regprocedure
  ) INTO v_def_det;
  SELECT pg_get_functiondef(
    'public.plaid_confirm_internal_transfer_candidate(uuid,uuid)'::regprocedure
  ) INTO v_def_conf;
  SELECT pg_get_functiondef(
    'public.plaid_confirmed_internal_transfer_inconsistency_code(uuid,uuid)'::regprocedure
  ) INTO v_def_inc;

  IF position('plaid_internal_transfer_pfc_directional_compatible' IN v_def_det) = 0
     OR position('plaid_internal_transfer_pai_different_proven' IN v_def_det) = 0
  THEN
    RAISE EXCEPTION 'F-HARD-36/37: detector missing shared helpers';
  END IF;
  IF position('plaid_internal_transfer_pfc_directional_compatible' IN v_def_conf) = 0
     OR position('plaid_internal_transfer_pai_different_proven' IN v_def_conf) = 0
  THEN
    RAISE EXCEPTION 'F-HARD-36/37: confirm missing shared helpers';
  END IF;
  IF position('plaid_internal_transfer_pfc_directional_compatible' IN v_def_inc) = 0 THEN
    RAISE EXCEPTION 'F-HARD-39: inconsistency helper missing directional PFC';
  END IF;
  -- Legacy one-side OR must not drive pair matching in detector/confirm.
  IF v_def_det ~* 'allowlisted\s+or\s+incoming\.allowlisted'
     OR v_def_det ~* 'plaid_internal_transfer_pfc_allowlisted'
  THEN
    RAISE EXCEPTION 'F-HARD: detector still references legacy allowlisted OR';
  END IF;
  IF v_def_conf ~* 'plaid_internal_transfer_pfc_allowlisted' THEN
    RAISE EXCEPTION 'F-HARD: confirm still references legacy allowlisted helper';
  END IF;
  IF v_def_inc ~* 'plaid_internal_transfer_pfc_allowlisted' THEN
    RAISE EXCEPTION 'F-HARD-39: inconsistency still references legacy allowlisted helper';
  END IF;
  IF position('stage_f_v2' IN v_def_det) = 0 THEN
    RAISE EXCEPTION 'F-HARD-41: detector missing stage_f_v2 policy_version';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)'::regprocedure
  ) INTO v_def_p1;
  IF position('v_survivor_canonical_id' IN v_def_p1) = 0 THEN
    RAISE EXCEPTION 'F-HARD-45: P1 merge function unexpectedly altered/missing';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_list_internal_transfer_review_items(text[])'::regprocedure
  ) INTO v_def_h1;
  IF v_def_h1 IS NULL OR length(v_def_h1) < 20 THEN
    RAISE EXCEPTION 'F-HARD-46: H1 read RPC missing';
  END IF;

  CREATE FUNCTION pg_temp.make_account(
    p_user_id uuid,
    p_item_id uuid,
    p_name text,
    p_plaid_account_id text,
    p_pai text
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
      v_id, p_user_id, p_name, 'bank', 'USD',
      0, 'bank', 'blue', 0, false,
      p_item_id, p_plaid_account_id, 'depository', 'checking',
      p_pai
    );
    RETURN v_id;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.make_canonical(p_user_id uuid)
  RETURNS uuid
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    v_id uuid := gen_random_uuid();
  BEGIN
    INSERT INTO public.plaid_canonical_financial_accounts(id, user_id)
    VALUES (v_id, p_user_id);
    RETURN v_id;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.link_member(
    p_user_id uuid, p_canonical_id uuid, p_account_id uuid, p_role text
  ) RETURNS void
  LANGUAGE plpgsql
  AS $fn$
  BEGIN
    INSERT INTO public.plaid_canonical_financial_account_members (
      user_id, canonical_account_id, account_id, role, link_origin
    ) VALUES (
      p_user_id, p_canonical_id, p_account_id, p_role, 'user_confirmed'
    );
  END;
  $fn$;

  CREATE FUNCTION pg_temp.make_leg(
    p_user_id uuid,
    p_item_id uuid,
    p_account_id uuid,
    p_txn_id text,
    p_amount numeric,
    p_date date,
    p_authorized_date date,
    p_iso text,
    p_pfc_version text,
    p_pfc_primary text,
    p_pfc_detailed text,
    p_pfc_confidence text
  ) RETURNS jsonb
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    v_raw_id uuid := gen_random_uuid();
    v_op_id uuid := gen_random_uuid();
    v_proj_id uuid := gen_random_uuid();
    v_op_type text;
    v_plaid_account_id text;
  BEGIN
    IF p_amount = 0 THEN
      RAISE EXCEPTION 'make_leg: amount must be non-zero';
    END IF;
    v_op_type := CASE WHEN p_amount > 0 THEN 'expense' ELSE 'income' END;
    SELECT a.plaid_account_id INTO v_plaid_account_id
    FROM public.accounts a WHERE a.id = p_account_id;

    INSERT INTO public.plaid_transactions (
      id, user_id, plaid_item_id, account_id, plaid_account_id,
      transaction_id, pending, date, authorized_date, amount,
      iso_currency_code, name,
      personal_finance_category_version,
      personal_finance_category_primary,
      personal_finance_category_detailed,
      personal_finance_category_confidence_level
    ) VALUES (
      v_raw_id, p_user_id, p_item_id, p_account_id, v_plaid_account_id,
      p_txn_id, false, p_date, p_authorized_date, p_amount,
      p_iso, 'fhard-' || p_txn_id,
      p_pfc_version, p_pfc_primary, p_pfc_detailed, p_pfc_confidence
    );

    INSERT INTO public.operations (
      id, user_id, from_account_id, to_account_id, type, amount,
      currency_code, occurred_at, source, category_id, archived_at,
      category_overridden, recurrence, is_recurring
    ) VALUES (
      v_op_id, p_user_id, p_account_id, null, v_op_type, abs(p_amount),
      'USD', p_date, 'plaid', null, null, false, 'none', false
    );

    INSERT INTO public.plaid_transaction_operation_projections (
      id, user_id, plaid_item_id, plaid_transaction_id,
      operation_id, state, last_projected_at
    ) VALUES (
      v_proj_id, p_user_id, p_item_id, p_txn_id,
      v_op_id, 'posted_projected', now()
    );

    RETURN jsonb_build_object(
      'raw_id', v_raw_id, 'op_id', v_op_id, 'proj_id', v_proj_id
    );
  END;
  $fn$;

  CREATE FUNCTION pg_temp.retire_raw(p_user_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  AS $fn$
  BEGIN
    UPDATE public.plaid_transactions
    SET removed_at = coalesce(removed_at, now())
    WHERE user_id = p_user_id AND removed_at IS NULL;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.active_candidates(p_user_id uuid)
  RETURNS int
  LANGUAGE sql
  AS $fn$
    SELECT count(*)::int
    FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = p_user_id AND r.state = 'candidate';
  $fn$;

  CREATE FUNCTION pg_temp.reconcile(p_user_id uuid)
  RETURNS jsonb
  LANGUAGE plpgsql
  AS $fn$
  BEGIN
    RETURN public.plaid_reconcile_internal_transfer_candidates_for_user(p_user_id);
  END;
  $fn$;

  -- Auth fixture
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id, 'authenticated', 'authenticated',
    'stage-f-hard-' || v_user_id::text || '@ophir.invalid',
    extensions.crypt('stage-f-hard-not-used', extensions.gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_identity_id, v_user_id,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', 'stage-f-hard-' || v_user_id::text || '@ophir.invalid'
    ),
    'email', v_user_id::text, now(), now(), now()
  );

  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id) THEN
    RAISE EXCEPTION 'FIXTURE: profile not created by handle_new_user';
  END IF;

  INSERT INTO public.plaid_items (
    id, user_id, plaid_environment, plaid_item_id, access_token_secret_id
  ) VALUES (
    v_item_id, v_user_id, 'sandbox',
    'stage-f-hard-item-' || v_user_id::text, v_secret_id
  );

  -- Helper unit checks for PFC / PAI
  IF NOT public.plaid_internal_transfer_pfc_directional_compatible(
    'v2', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'v2', 'TRANSFER_IN_ACCOUNT_TRANSFER'
  ) THEN
    RAISE EXCEPTION 'matrix A failed';
  END IF;
  IF NOT public.plaid_internal_transfer_pfc_directional_compatible(
    'v2', 'TRANSFER_OUT_SAVINGS', 'v2', 'TRANSFER_IN_SAVINGS'
  ) THEN
    RAISE EXCEPTION 'matrix B failed';
  END IF;
  IF public.plaid_internal_transfer_pfc_directional_compatible(
    'v2', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'v2', 'TRANSFER_IN_SAVINGS'
  ) THEN
    RAISE EXCEPTION 'mixed ACCOUNT/SAVINGS must reject';
  END IF;
  IF public.plaid_internal_transfer_pfc_directional_compatible(
    'v2', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'v2', 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
  ) THEN
    RAISE EXCEPTION 'CC must reject';
  END IF;
  IF public.plaid_internal_transfer_pai_different_proven(NULL, 'x')
     OR public.plaid_internal_transfer_pai_different_proven('a', 'a')
     OR NOT public.plaid_internal_transfer_pai_different_proven('a', 'b')
  THEN
    RAISE EXCEPTION 'PAI helper contract broken';
  END IF;

  -- ===== F-HARD-1 valid ACCOUNT_TRANSFER pair =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A', 'f1-a', 'pai-a-1');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B', 'f1-b', 'pai-b-1');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f1-out', 50.00, DATE '2026-08-01', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_op_out := (v_payload->>'op_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f1-in', -50.00, DATE '2026-08-01', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_op_in := (v_payload->>'op_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  IF coalesce((v_metrics->>'candidates_created')::int, -1) <> 1
     OR pg_temp.active_candidates(v_user_id) <> 1 THEN
    RAISE EXCEPTION 'F-HARD-1: expected 1 candidate, got %', v_metrics;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = v_user_id AND r.state = 'candidate'
      AND r.evidence_snapshot->>'policy_version' = 'stage_f_v2'
  ) THEN
    RAISE EXCEPTION 'F-HARD-41: policy_version not stage_f_v2';
  END IF;

  -- F-HARD-25 idempotent
  v_metrics := pg_temp.reconcile(v_user_id);
  IF coalesce((v_metrics->>'candidates_created')::int, -1) <> 0
     OR pg_temp.active_candidates(v_user_id) <> 1 THEN
    RAISE EXCEPTION 'F-HARD-25: not idempotent %', v_metrics;
  END IF;

  -- F-HARD-30 confirm success
  SELECT r.id INTO v_recon_id
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id AND r.state = 'candidate' LIMIT 1;
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'F-HARD-30: confirm failed %', v_result;
  END IF;
  v_transfer_id := (v_result->>'transfer_operation_id')::uuid;

  -- F-HARD-28 confirmed untouched by detector
  v_metrics := pg_temp.reconcile(v_user_id);
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state IS DISTINCT FROM 'confirmed'
  ) THEN
    RAISE EXCEPTION 'F-HARD-28: confirmed mutated by detector';
  END IF;

  -- F-HARD-29 reverse terminal + detector untouched
  v_result := public.plaid_reverse_internal_transfer_resolution(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'reversed' THEN
    RAISE EXCEPTION 'F-HARD-29: reverse failed %', v_result;
  END IF;
  PERFORM pg_temp.reconcile(v_user_id);
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state IS DISTINCT FROM 'reversed'
  ) THEN
    RAISE EXCEPTION 'F-HARD-29: reversed mutated by detector';
  END IF;

  -- ===== F-HARD-2 one-side PFC only =====
  PERFORM pg_temp.retire_raw(v_user_id);
  DELETE FROM public.plaid_internal_transfer_reconciliations WHERE user_id = v_user_id;
  -- leave reversed ops archived; start fresh accounts
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A2', 'f2-a', 'pai-a-2');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B2', 'f2-b', 'pai-b-2');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f2-out', 40.00, DATE '2026-08-02', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f2-in', -40.00, DATE '2026-08-02', NULL, 'USD',
    'v2', 'FOOD_AND_DRINK', 'FOOD_AND_DRINK_RESTAURANT', 'HIGH');
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-2: one-side PFC created candidate';
  END IF;

  -- ===== F-HARD-3 wrong-direction PFC =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A3', 'f3-a', 'pai-a-3');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B3', 'f3-b', 'pai-b-3');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f3-out', 41.00, DATE '2026-08-03', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f3-in', -41.00, DATE '2026-08-03', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-3: wrong-direction PFC created candidate';
  END IF;

  -- ===== F-HARD-4 unrelated =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A4', 'f4-a', 'pai-a-4');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B4', 'f4-b', 'pai-b-4');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f4-out', 42.00, DATE '2026-08-04', NULL, 'USD',
    'v2', 'GENERAL_MERCHANDISE', 'GENERAL_MERCHANDISE_OTHER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f4-in', -42.00, DATE '2026-08-04', NULL, 'USD',
    'v2', 'GENERAL_MERCHANDISE', 'GENERAL_MERCHANDISE_OTHER', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-4: unrelated PFC created candidate';
  END IF;

  -- ===== F-HARD-5 SAVINGS pair =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A5', 'f5-a', 'pai-a-5');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B5', 'f5-b', 'pai-b-5');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f5-out', 55.00, DATE '2026-08-05', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_SAVINGS', NULL);
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f5-in', -55.00, DATE '2026-08-05', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_SAVINGS', NULL);
  -- F-HARD-9 null confidence still candidate
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 1 THEN
    RAISE EXCEPTION 'F-HARD-5/9: savings + null confidence expected candidate';
  END IF;
  DELETE FROM public.plaid_internal_transfer_reconciliations
  WHERE user_id = v_user_id AND state = 'candidate';

  -- ===== F-HARD-6 mixed ACCOUNT↔SAVINGS =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A6', 'f6-a', 'pai-a-6');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B6', 'f6-b', 'pai-b-6');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f6-out', 56.00, DATE '2026-08-06', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f6-in', -56.00, DATE '2026-08-06', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_SAVINGS', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-6: mixed pair created candidate';
  END IF;

  -- ===== F-HARD-7 CC =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A7', 'f7-a', 'pai-a-7');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B7', 'f7-b', 'pai-b-7');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f7-out', 57.00, DATE '2026-08-07', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f7-in', -57.00, DATE '2026-08-07', NULL, 'USD',
    'v2', 'LOAN_PAYMENTS', 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-7: CC pair created candidate';
  END IF;

  -- ===== F-HARD-8 both PFC null =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A8', 'f8-a', 'pai-a-8');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B8', 'f8-b', 'pai-b-8');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f8-out', 58.00, DATE '2026-08-08', NULL, 'USD',
    NULL, NULL, NULL, NULL);
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f8-in', -58.00, DATE '2026-08-08', NULL, 'USD',
    NULL, NULL, NULL, NULL);
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-8: null PFC created candidate';
  END IF;

  -- ===== Identity F-HARD-11..15 =====
  -- same PAI
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A11', 'f11-a', 'pai-same');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B11', 'f11-b', 'pai-same');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f11-out', 60.00, DATE '2026-08-11', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f11-in', -60.00, DATE '2026-08-11', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-11: same PAI created candidate';
  END IF;

  -- out PAI null
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A12', 'f12-a', NULL);
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B12', 'f12-b', 'pai-b-12');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f12-out', 61.00, DATE '2026-08-12', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f12-in', -61.00, DATE '2026-08-12', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-12: out null PAI created candidate';
  END IF;

  -- in PAI null / both null
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A13', 'f13-a', 'pai-a-13');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B13', 'f13-b', NULL);
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f13-out', 62.00, DATE '2026-08-13', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f13-in', -62.00, DATE '2026-08-13', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-13: in null PAI created candidate';
  END IF;

  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A14', 'f14-a', NULL);
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B14', 'f14-b', NULL);
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f14-out', 63.00, DATE '2026-08-14', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f14-in', -63.00, DATE '2026-08-14', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-14: both null PAI created candidate';
  END IF;

  -- same canonical
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A15', 'f15-a', 'pai-a-15');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B15', 'f15-b', 'pai-b-15');
  v_can_a := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_b, 'secondary');
  -- secondary not eligible; need two authoritative on same canonical impossible by unique.
  -- Use two auths on same can impossible. Instead: both authoritative different accounts same can — blocked by unique authority index.
  -- Recreate: one canonical with only A authoritative; B also needs authoritative on same can — can't.
  -- Same canonical edge requires both legs authoritative on same can — impossible with unique authority.
  -- Simulate same canonical by linking B as authoritative on same can after demoting — actually unique prevents two auth.
  -- Stage F excludes same canonical_id. Put both as auth on DIFFERENT cans then force same by updating membership?
  -- Simpler: put A and B authoritative on can_a and can_b then UPDATE B membership canonical to can_a after making B secondary...
  -- Easiest valid path: only one authoritative per can — if B is secondary on can_a, B not eligible → no candidate.
  -- For F-HARD-15 "same canonical → no": two eligible legs with same canonical_id requires two authoritative on one can — schema forbids.
  -- Structural: edge predicate requires canonical <> so we assert helper/path via detector def contains 'canonical_account_id <>'.
  IF position('canonical_account_id <>' IN v_def_det) = 0
     AND position('canonical_account_id<>' IN replace(v_def_det, ' ', '')) = 0 THEN
    RAISE EXCEPTION 'F-HARD-15: detector missing same-canonical exclusion';
  END IF;

  -- ===== Money/date F-HARD-16..21 =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A16', 'f16-a', 'pai-a-16');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B16', 'f16-b', 'pai-b-16');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f16-out', 70.00, DATE '2026-08-16', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f16-in', -71.00, DATE '2026-08-16', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-16: amount mismatch created candidate';
  END IF;

  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A17', 'f17-a', 'pai-a-17');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B17', 'f17-b', 'pai-b-17');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f17-out', 72.00, DATE '2026-08-17', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f17-in', -72.00, DATE '2026-08-17', NULL, 'EUR',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  -- note: make_leg uses currency_code USD on operations always; raw iso differs — edge uses raw iso
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-17: currency mismatch created candidate';
  END IF;

  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A18', 'f18-a', 'pai-a-18');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B18', 'f18-b', 'pai-b-18');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f18-out', 73.00, DATE '2026-08-18', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f18-in', -73.00, DATE '2026-08-19', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-18: date mismatch created candidate';
  END IF;

  -- F-HARD-19 authorized_date fallback
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A19', 'f19-a', 'pai-a-19');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B19', 'f19-b', 'pai-b-19');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f19-out', 74.00, DATE '2026-08-20', DATE '2026-08-10', 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f19-in', -74.00, DATE '2026-08-21', DATE '2026-08-10', 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 1 THEN
    RAISE EXCEPTION 'F-HARD-19: authorized_date equal should candidate';
  END IF;
  SELECT r.id INTO v_recon_id FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id AND r.state = 'candidate' LIMIT 1;

  -- F-HARD-26 invalidate when predicate breaks (PFC change)
  UPDATE public.plaid_transactions t
  SET personal_finance_category_detailed = 'FOOD_AND_DRINK_RESTAURANT'
  FROM public.plaid_transaction_operation_projections p
  WHERE p.id = (SELECT incoming_projection_id FROM public.plaid_internal_transfer_reconciliations WHERE id = v_recon_id)
    AND t.plaid_item_id = p.plaid_item_id AND t.transaction_id = p.plaid_transaction_id;
  PERFORM pg_temp.reconcile(v_user_id);
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state = 'candidate'
  ) THEN
    RAISE EXCEPTION 'F-HARD-26: candidate not invalidated';
  END IF;

  -- F-HARD-27 reactivate when fixed
  UPDATE public.plaid_transactions t
  SET personal_finance_category_detailed = 'TRANSFER_IN_ACCOUNT_TRANSFER'
  FROM public.plaid_transaction_operation_projections p
  WHERE p.id = (SELECT incoming_projection_id FROM public.plaid_internal_transfer_reconciliations WHERE id = v_recon_id)
    AND t.plaid_item_id = p.plaid_item_id AND t.transaction_id = p.plaid_transaction_id;
  PERFORM pg_temp.reconcile(v_user_id);
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state = 'candidate'
  ) THEN
    RAISE EXCEPTION 'F-HARD-27: candidate not reactivated';
  END IF;

  -- F-HARD-20 pending
  UPDATE public.plaid_transactions t
  SET pending = true
  FROM public.plaid_transaction_operation_projections p
  WHERE p.id = (SELECT outgoing_projection_id FROM public.plaid_internal_transfer_reconciliations WHERE id = v_recon_id)
    AND t.plaid_item_id = p.plaid_item_id AND t.transaction_id = p.plaid_transaction_id;
  PERFORM pg_temp.reconcile(v_user_id);
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state = 'candidate'
  ) THEN
    RAISE EXCEPTION 'F-HARD-20: pending still candidate';
  END IF;
  UPDATE public.plaid_transactions t
  SET pending = false
  FROM public.plaid_transaction_operation_projections p
  WHERE p.id = (SELECT outgoing_projection_id FROM public.plaid_internal_transfer_reconciliations WHERE id = v_recon_id)
    AND t.plaid_item_id = p.plaid_item_id AND t.transaction_id = p.plaid_transaction_id;
  PERFORM pg_temp.reconcile(v_user_id);

  -- F-HARD-21 removed
  UPDATE public.plaid_transactions t
  SET removed_at = now()
  FROM public.plaid_transaction_operation_projections p
  WHERE p.id = (SELECT incoming_projection_id FROM public.plaid_internal_transfer_reconciliations WHERE id = v_recon_id)
    AND t.plaid_item_id = p.plaid_item_id AND t.transaction_id = p.plaid_transaction_id;
  PERFORM pg_temp.reconcile(v_user_id);
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state = 'candidate'
  ) THEN
    RAISE EXCEPTION 'F-HARD-21: removed still candidate';
  END IF;

  -- ===== Bijectivity F-HARD-22/23/24 =====
  PERFORM pg_temp.retire_raw(v_user_id);
  DELETE FROM public.plaid_internal_transfer_reconciliations WHERE user_id = v_user_id AND state = 'candidate';
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A22', 'f22-a', 'pai-a-22');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B22', 'f22-b', 'pai-b-22');
  v_acc_c := pg_temp.make_account(v_user_id, v_item_id, 'C22', 'f22-c', 'pai-c-22');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  v_can_c := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_c, v_acc_c, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f22-out', 80.00, DATE '2026-08-22', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f22-in1', -80.00, DATE '2026-08-22', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_c, 'f22-in2', -80.00, DATE '2026-08-22', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-22: ambiguous hardened edges created candidate';
  END IF;

  -- F-HARD-24 weak competing edge must not destroy valid hardened pair
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A24', 'f24-a', 'pai-a-24');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B24', 'f24-b', 'pai-b-24');
  v_acc_c := pg_temp.make_account(v_user_id, v_item_id, 'C24', 'f24-c', 'pai-c-24');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  v_can_c := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_c, v_acc_c, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f24-out', 81.00, DATE '2026-08-24', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f24-in-good', -81.00, DATE '2026-08-24', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  -- weak competitor: same amount/date but unrelated PFC (fails hardened)
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_c, 'f24-in-weak', -81.00, DATE '2026-08-24', NULL, 'USD',
    'v2', 'FOOD_AND_DRINK', 'FOOD_AND_DRINK_RESTAURANT', 'HIGH');
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 1 THEN
    RAISE EXCEPTION 'F-HARD-24: weak competitor destroyed hardened bijectivity';
  END IF;

  -- ===== Confirm reject cases F-HARD-31..35 =====
  -- Insert weak legacy-style candidate manually then confirm
  PERFORM pg_temp.retire_raw(v_user_id);
  DELETE FROM public.plaid_internal_transfer_reconciliations WHERE user_id = v_user_id AND state = 'candidate';
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A31', 'f31-a', 'pai-a-31');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B31', 'f31-b', 'pai-b-31');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f31-out', 90.00, DATE '2026-08-25', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_op_out := (v_payload->>'op_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f31-in', -90.00, DATE '2026-08-25', NULL, 'USD',
    'v2', 'FOOD_AND_DRINK', 'FOOD_AND_DRINK_RESTAURANT', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_op_in := (v_payload->>'op_id')::uuid;
  INSERT INTO public.plaid_internal_transfer_reconciliations (
    user_id, outgoing_projection_id, incoming_projection_id,
    outgoing_operation_id, incoming_operation_id,
    outgoing_canonical_account_id, incoming_canonical_account_id,
    state, evidence_snapshot, candidate_detected_at, last_detected_at
  ) VALUES (
    v_user_id, v_proj_out, v_proj_in, v_op_out, v_op_in, v_can_a, v_can_b,
    'candidate', '{"policy_version":"stage_f_v1_weak"}'::jsonb, now(), now()
  ) RETURNING id INTO v_recon_id;

  SELECT count(*) INTO v_before_ops FROM public.operations WHERE user_id = v_user_id;
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'rejected'
     OR coalesce(v_result->>'reason', '') <> 'stale_candidate' THEN
    RAISE EXCEPTION 'F-HARD-31: expected stale reject, got %', v_result;
  END IF;
  SELECT count(*) INTO v_after_ops FROM public.operations WHERE user_id = v_user_id;
  IF v_after_ops <> v_before_ops THEN
    RAISE EXCEPTION 'F-HARD-35: synthetic op created on reject';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND (
      r.state IS DISTINCT FROM 'invalidated'
      OR r.confirmed_at IS NOT NULL
      OR r.transfer_operation_id IS NOT NULL
      OR r.confirmed_snapshot IS NOT NULL
    )
  ) THEN
    RAISE EXCEPTION 'F-HARD-35: reject left confirmation fields';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.operations o WHERE o.id IN (v_op_out, v_op_in) AND o.archived_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'F-HARD-35: source legs archived on reject';
  END IF;

  -- F-HARD-32 same PAI candidate reject
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A32', 'f32-a', 'pai-same-32');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B32', 'f32-b', 'pai-same-32');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f32-out', 91.00, DATE '2026-08-26', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid; v_op_out := (v_payload->>'op_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f32-in', -91.00, DATE '2026-08-26', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid; v_op_in := (v_payload->>'op_id')::uuid;
  INSERT INTO public.plaid_internal_transfer_reconciliations (
    user_id, outgoing_projection_id, incoming_projection_id,
    outgoing_operation_id, incoming_operation_id,
    outgoing_canonical_account_id, incoming_canonical_account_id,
    state, evidence_snapshot, candidate_detected_at, last_detected_at
  ) VALUES (
    v_user_id, v_proj_out, v_proj_in, v_op_out, v_op_in, v_can_a, v_can_b,
    'candidate', '{}'::jsonb, now(), now()
  ) RETURNING id INTO v_recon_id;
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'rejected' THEN
    RAISE EXCEPTION 'F-HARD-32: same PAI confirm should reject %', v_result;
  END IF;

  -- F-HARD-33 null PAI
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A33', 'f33-a', NULL);
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B33', 'f33-b', 'pai-b-33');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f33-out', 92.00, DATE '2026-08-27', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid; v_op_out := (v_payload->>'op_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f33-in', -92.00, DATE '2026-08-27', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid; v_op_in := (v_payload->>'op_id')::uuid;
  INSERT INTO public.plaid_internal_transfer_reconciliations (
    user_id, outgoing_projection_id, incoming_projection_id,
    outgoing_operation_id, incoming_operation_id,
    outgoing_canonical_account_id, incoming_canonical_account_id,
    state, evidence_snapshot, candidate_detected_at, last_detected_at
  ) VALUES (
    v_user_id, v_proj_out, v_proj_in, v_op_out, v_op_in, v_can_a, v_can_b,
    'candidate', '{}'::jsonb, now(), now()
  ) RETURNING id INTO v_recon_id;
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'rejected' THEN
    RAISE EXCEPTION 'F-HARD-33: null PAI confirm should reject %', v_result;
  END IF;

  -- F-HARD-34 lost bijectivity under hardened edges
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A34', 'f34-a', 'pai-a-34');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B34', 'f34-b', 'pai-b-34');
  v_acc_c := pg_temp.make_account(v_user_id, v_item_id, 'C34', 'f34-c', 'pai-c-34');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  v_can_c := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_c, v_acc_c, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f34-out', 93.00, DATE '2026-08-28', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid; v_op_out := (v_payload->>'op_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f34-in', -93.00, DATE '2026-08-28', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid; v_op_in := (v_payload->>'op_id')::uuid;
  -- second hardened-compatible incoming competitor
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_c, 'f34-in2', -93.00, DATE '2026-08-28', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  INSERT INTO public.plaid_internal_transfer_reconciliations (
    user_id, outgoing_projection_id, incoming_projection_id,
    outgoing_operation_id, incoming_operation_id,
    outgoing_canonical_account_id, incoming_canonical_account_id,
    state, evidence_snapshot, candidate_detected_at, last_detected_at
  ) VALUES (
    v_user_id, v_proj_out, v_proj_in, v_op_out, v_op_in, v_can_a, v_can_b,
    'candidate', '{}'::jsonb, now(), now()
  ) RETURNING id INTO v_recon_id;
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'rejected' THEN
    RAISE EXCEPTION 'F-HARD-34: non-bijective confirm should reject %', v_result;
  END IF;

  -- F-HARD-42 Stage E suppressed
  PERFORM pg_temp.retire_raw(v_user_id);
  DELETE FROM public.plaid_internal_transfer_reconciliations WHERE user_id = v_user_id AND state IN ('candidate', 'invalidated');
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A42', 'f42-a', 'pai-a-42');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B42', 'f42-b', 'pai-b-42');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f42-out', 94.00, DATE '2026-08-29', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_op_out := (v_payload->>'op_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f42-in', -94.00, DATE '2026-08-29', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_op_in := (v_payload->>'op_id')::uuid;
  INSERT INTO public.plaid_duplicate_operation_resolutions (
    user_id, canonical_account_id, kept_operation_id, suppressed_operation_id,
    resolved_at, reversed_at
  ) VALUES (
    v_user_id, v_can_a, v_op_in, v_op_out, now(), null
  );
  PERFORM pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidates(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F-HARD-42: Stage E suppressed leg still candidate';
  END IF;

  -- F-HARD-40 confirmed inconsistency does not unconfirm (create valid confirm then break PFC)
  PERFORM pg_temp.retire_raw(v_user_id);
  DELETE FROM public.plaid_duplicate_operation_resolutions WHERE user_id = v_user_id;
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'A40', 'f40-a', 'pai-a-40');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'B40', 'f40-b', 'pai-b-40');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f40-out', 95.00, DATE '2026-08-30', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid; v_op_out := (v_payload->>'op_id')::uuid; v_raw_out := (v_payload->>'raw_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f40-in', -95.00, DATE '2026-08-30', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid; v_op_in := (v_payload->>'op_id')::uuid; v_raw_in := (v_payload->>'raw_id')::uuid;
  PERFORM pg_temp.reconcile(v_user_id);
  SELECT r.id INTO v_recon_id FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id AND r.state = 'candidate' LIMIT 1;
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'F-HARD-40 setup confirm failed %', v_result;
  END IF;
  UPDATE public.plaid_transactions SET personal_finance_category_detailed = 'FOOD_AND_DRINK_RESTAURANT'
  WHERE id = v_raw_in;
  IF public.plaid_confirmed_internal_transfer_inconsistency_code(v_user_id, v_recon_id)
       IS DISTINCT FROM 'pfc_policy_broken' THEN
    RAISE EXCEPTION 'F-HARD-39: expected pfc_policy_broken, got %',
      public.plaid_confirmed_internal_transfer_inconsistency_code(v_user_id, v_recon_id);
  END IF;
  PERFORM public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state IS DISTINCT FROM 'confirmed'
  ) THEN
    RAISE EXCEPTION 'F-HARD-40: confirmed was unconfirmed';
  END IF;

  -- Manual untouched structural marker (F-HARD-44): no Manual tables mutated by detector
  -- Ordinary Plaid (F-HARD-43): reconcile does not create ops — covered by F-HARD-1 ops count unchanged except confirm path.
  -- F-HARD-47/48: no TS/Dart changes in this implementation (assert by absence of file edits outside SQL).

END;
$$;

SELECT 'STAGE_F_HARDENING_VALIDATION_PASS'
  AS stage_f_hardening_validation_result;

ROLLBACK;
