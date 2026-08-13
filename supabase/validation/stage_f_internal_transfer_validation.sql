-- =============================================================================
-- Stage F validation harness (F1–F19)
-- Temporary / non-migration SQL. Does not change production schema or RPCs.
-- Run as: postgres against linked Supabase DB.
-- One transaction; ends with ROLLBACK. No leftover fixture data.
-- No Plaid API / workers / Edge Functions / production DDL changes.
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_user_id uuid := 'f0131700-0000-4000-8000-000000000001';
  v_item_id uuid := 'f0131700-0000-4000-8000-000000000010';
  v_secret_id uuid := 'f0131700-0000-4000-8000-0000000000ff';
  v_identity_id uuid := 'f0131700-0000-4000-8000-0000000000aa';

  v_metrics jsonb;
  v_payload jsonb;
  v_def text;

  v_acc_a uuid;
  v_acc_b uuid;
  v_acc_c uuid;
  v_acc_d uuid;
  v_can_a uuid;
  v_can_b uuid;
  v_can_c uuid;
  v_can_d uuid;

  v_raw_out uuid;
  v_raw_in uuid;
  v_op_out uuid;
  v_op_in uuid;
  v_op_kept uuid;
  v_proj_out uuid;
  v_proj_in uuid;
  v_proj_out2 uuid;
  v_proj_in2 uuid;

  v_recon_id uuid;
  v_recon_id_2 uuid;
  v_detected_at timestamptz;
  v_detected_at_2 timestamptz;
  v_state text;
  v_inv_at timestamptz;
  v_match_reason text;
  v_conf_out text;
  v_conf_in text;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id = v_user_id) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: auth.users id % exists', v_user_id;
  END IF;
  IF EXISTS (SELECT 1 FROM public.plaid_items i WHERE i.id = v_item_id) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: plaid_items id % exists', v_item_id;
  END IF;

  CREATE TEMP TABLE ops_baseline (
    id uuid PRIMARY KEY,
    body jsonb NOT NULL
  ) ON COMMIT DROP;

  CREATE FUNCTION pg_temp.register_ops(p_user_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  AS $fn$
  BEGIN
    INSERT INTO ops_baseline(id, body)
    SELECT o.id, to_jsonb(o)
    FROM public.operations o
    WHERE o.user_id = p_user_id
    ON CONFLICT (id) DO NOTHING;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.assert_ops_unchanged(p_case text, p_user_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    r record;
  BEGIN
    FOR r IN
      SELECT b.id, b.body AS before_body, to_jsonb(o) AS after_body
      FROM ops_baseline b
      JOIN public.operations o ON o.id = b.id
      WHERE o.user_id = p_user_id
    LOOP
      IF r.before_body IS DISTINCT FROM r.after_body THEN
        RAISE EXCEPTION '%: operation mutated id=%', p_case, r.id;
      END IF;
    END LOOP;

    IF EXISTS (
      SELECT 1
      FROM ops_baseline b
      WHERE NOT EXISTS (SELECT 1 FROM public.operations o WHERE o.id = b.id)
    ) THEN
      RAISE EXCEPTION '%: baseline operation disappeared', p_case;
    END IF;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.retire_raw(p_user_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  AS $fn$
  BEGIN
    UPDATE public.plaid_transactions
    SET removed_at = coalesce(removed_at, now())
    WHERE user_id = p_user_id
      AND removed_at IS NULL;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.reconcile(p_user_id uuid)
  RETURNS jsonb
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    m jsonb;
  BEGIN
    PERFORM pg_temp.register_ops(p_user_id);
    m := public.plaid_reconcile_internal_transfer_candidates_for_user(p_user_id);
    PERFORM pg_temp.assert_ops_unchanged('F19', p_user_id);
    RETURN m;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.make_account(
    p_user_id uuid,
    p_item_id uuid,
    p_name text,
    p_type text,
    p_plaid_account_id text
  ) RETURNS uuid
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    v_id uuid := gen_random_uuid();
  BEGIN
    INSERT INTO public.accounts (
      id, user_id, name, type, currency_code,
      initial_balance, icon_key, color_key, sort_order, is_archived,
      plaid_item_id, plaid_account_id, plaid_type, plaid_subtype
    ) VALUES (
      v_id, p_user_id, p_name, p_type, 'USD',
      0, 'bank', 'blue', 0, false,
      p_item_id, p_plaid_account_id, p_type, p_type
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
    p_user_id uuid,
    p_canonical_id uuid,
    p_account_id uuid,
    p_role text
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
    FROM public.accounts a
    WHERE a.id = p_account_id;

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
      p_iso, 'stage-f-fixture-' || p_txn_id,
      p_pfc_version, p_pfc_primary, p_pfc_detailed, p_pfc_confidence
    );

    INSERT INTO public.operations (
      id, user_id, from_account_id, to_account_id, type, amount,
      currency_code, occurred_at, source, category_id, archived_at,
      category_overridden, recurrence
    ) VALUES (
      v_op_id, p_user_id, p_account_id, null, v_op_type, abs(p_amount),
      'USD', p_date, 'plaid', null, null,
      false, 'none'
    );

    INSERT INTO public.plaid_transaction_operation_projections (
      id, user_id, plaid_item_id, plaid_transaction_id,
      operation_id, state, last_projected_at
    ) VALUES (
      v_proj_id, p_user_id, p_item_id, p_txn_id,
      v_op_id, 'posted_projected', now()
    );

    RETURN jsonb_build_object(
      'raw_id', v_raw_id,
      'op_id', v_op_id,
      'proj_id', v_proj_id
    );
  END;
  $fn$;

  CREATE FUNCTION pg_temp.active_candidate_count(p_user_id uuid)
  RETURNS int
  LANGUAGE sql
  AS $fn$
    SELECT count(*)::int
    FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = p_user_id
      AND r.state = 'candidate';
  $fn$;

  -- Auth fixture (profile via handle_new_user)
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    'stage-f-validation-' || v_user_id::text || '@ophir.invalid',
    extensions.crypt('stage-f-validation-not-used', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    '', '', '', ''
  );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_identity_id,
    v_user_id,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', 'stage-f-validation-' || v_user_id::text || '@ophir.invalid'
    ),
    'email',
    v_user_id::text,
    now(), now(), now()
  );

  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id) THEN
    RAISE EXCEPTION 'FIXTURE: profile not created by handle_new_user';
  END IF;

  INSERT INTO public.plaid_items (
    id, user_id, plaid_environment, plaid_item_id, access_token_secret_id
  ) VALUES (
    v_item_id, v_user_id, 'sandbox',
    'stage-f-item-' || v_user_id::text,
    v_secret_id
  );

  -- ===== F1: checking ↔ savings allowlisted → 1 candidate =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F1 Checking', 'bank', 'f1-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F1 Savings', 'savings', 'f1-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f1-out', 100.00, DATE '2026-08-01', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_raw_out := (v_payload->>'raw_id')::uuid;
  v_op_out := (v_payload->>'op_id')::uuid;
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f1-in', -100.00, DATE '2026-08-01', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_raw_in := (v_payload->>'raw_id')::uuid;
  v_op_in := (v_payload->>'op_id')::uuid;
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  IF coalesce((v_metrics->>'candidates_created')::int, -1) <> 1 THEN
    RAISE EXCEPTION 'F1: expected candidates_created=1, got %', v_metrics;
  END IF;
  IF pg_temp.active_candidate_count(v_user_id) <> 1 THEN
    RAISE EXCEPTION 'F1: expected exactly 1 active candidate';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = v_user_id
      AND r.outgoing_projection_id = v_proj_out
      AND r.incoming_projection_id = v_proj_in
      AND r.state = 'candidate'
  ) THEN
    RAISE EXCEPTION 'F1: missing expected candidate pair';
  END IF;

  -- ===== F2: checking → CC payment =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F2 Checking', 'bank', 'f2-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F2 Credit', 'credit_card', 'f2-cc');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f2-out', 250.00, DATE '2026-08-02', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'VERY_HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f2-in', -250.00, DATE '2026-08-02', NULL, 'USD',
    'v2', 'LOAN_PAYMENTS', 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidate_count(v_user_id) <> 1 THEN
    RAISE EXCEPTION 'F2: expected 1 active candidate, metrics=%', v_metrics;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = v_user_id
      AND r.outgoing_projection_id = v_proj_out
      AND r.incoming_projection_id = v_proj_in
      AND r.state = 'candidate'
  ) THEN
    RAISE EXCEPTION 'F2: missing CC payment candidate';
  END IF;

  -- ===== F3: single-sided → 0 =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F3 Checking', 'bank', 'f3-chk');
  v_can_a := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f3-out', 80.00, DATE '2026-08-03', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidate_count(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F3: expected 0 candidates, metrics=%', v_metrics;
  END IF;

  -- ===== F4: one leg without canonical membership → 0 =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F4 Checking', 'bank', 'f4-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F4 Savings', 'savings', 'f4-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f4-out', 90.00, DATE '2026-08-04', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f4-in', -90.00, DATE '2026-08-04', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidate_count(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F4: expected 0 candidates, metrics=%', v_metrics;
  END IF;

  -- ===== F5: secondary membership on one leg → 0 =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F5 Checking', 'bank', 'f5-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F5 Savings', 'savings', 'f5-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'secondary');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f5-out', 70.00, DATE '2026-08-05', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f5-in', -70.00, DATE '2026-08-05', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidate_count(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F5: expected 0 candidates, metrics=%', v_metrics;
  END IF;

  -- ===== F6: STRUCTURALLY VERIFIED =====
  -- Runtime "two eligible authoritative legs on same canonical" is schema-impossible:
  -- Stage F requires role='authoritative' for eligibility, but Stage A unique index
  -- plaid_canonical_financial_account_members_active_authority_uidx allows at most
  -- one active authoritative member per canonical_account_id.
  SELECT pg_get_functiondef(
    'public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)'::regprocedure
  ) INTO v_def;
  IF v_def IS NULL OR position('canonical_account_id <>' IN v_def) = 0 THEN
    RAISE EXCEPTION 'F6: RPC missing different-canonical predicate';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.plaid_internal_transfer_reconciliations'::regclass
      AND conname = 'plaid_internal_transfer_reconciliations_canonical_distinct_check'
  ) THEN
    RAISE EXCEPTION 'F6: missing reconciliations canonical-distinct table check';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_canonical_financial_account_members_active_authority_uidx'
  ) THEN
    RAISE EXCEPTION 'F6: missing active authoritative unique index';
  END IF;
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F6 A', 'bank', 'f6-a');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F6 B', 'savings', 'f6-b');
  v_can_a := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  BEGIN
    PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_b, 'authoritative');
    RAISE EXCEPTION 'F6: expected unique_violation for second authoritative';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;

  -- ===== F7: active Stage E suppressed leg → 0 =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F7 Checking', 'bank', 'f7-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F7 Savings', 'savings', 'f7-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f7-out', 55.00, DATE '2026-08-07', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f7-in', -55.00, DATE '2026-08-07', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_op_in := (v_payload->>'op_id')::uuid;
  v_op_kept := gen_random_uuid();
  INSERT INTO public.operations (
    id, user_id, from_account_id, to_account_id, type, amount,
    currency_code, occurred_at, source, category_id, archived_at,
    category_overridden, recurrence
  ) VALUES (
    v_op_kept, v_user_id, v_acc_b, null, 'income', 55.00,
    'USD', DATE '2026-08-07', 'plaid', null, null, false, 'none'
  );
  INSERT INTO public.plaid_duplicate_operation_resolutions (
    user_id, canonical_account_id, kept_operation_id, suppressed_operation_id,
    resolved_at, reversed_at
  ) VALUES (
    v_user_id, v_can_b, v_op_kept, v_op_in, now(), null
  );
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidate_count(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F7: expected 0 candidates, metrics=%', v_metrics;
  END IF;

  -- ===== F8: ambiguous 2×2 @ $100 → 0 =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F8 Out1', 'bank', 'f8-o1');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F8 Out2', 'bank', 'f8-o2');
  v_acc_c := pg_temp.make_account(v_user_id, v_item_id, 'F8 In1', 'savings', 'f8-i1');
  v_acc_d := pg_temp.make_account(v_user_id, v_item_id, 'F8 In2', 'savings', 'f8-i2');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  v_can_c := pg_temp.make_canonical(v_user_id);
  v_can_d := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_c, v_acc_c, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_d, v_acc_d, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f8-o1', 100.00, DATE '2026-08-08', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f8-o2', 100.00, DATE '2026-08-08', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out2 := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_c, 'f8-i1', -100.00, DATE '2026-08-08', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_d, 'f8-i2', -100.00, DATE '2026-08-08', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in2 := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidate_count(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F8: expected 0 candidates for ambiguous set, metrics=%', v_metrics;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = v_user_id
      AND r.state = 'candidate'
      AND r.outgoing_projection_id IN (v_proj_out, v_proj_out2)
  ) THEN
    RAISE EXCEPTION 'F8: arbitrary ambiguous pair selected';
  END IF;

  -- ===== F9: exact date → match_reason=exact_date =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F9 Checking', 'bank', 'f9-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F9 Savings', 'savings', 'f9-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f9-out', 33.00, DATE '2026-08-09', DATE '2026-08-08', 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_SAVINGS', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f9-in', -33.00, DATE '2026-08-09', DATE '2026-08-07', 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_SAVINGS', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id, r.evidence_snapshot->>'match_reason'
    INTO v_recon_id, v_match_reason
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in
    AND r.state = 'candidate';
  IF v_recon_id IS NULL THEN
    RAISE EXCEPTION 'F9: expected candidate, metrics=%', v_metrics;
  END IF;
  IF v_match_reason IS DISTINCT FROM 'exact_date' THEN
    RAISE EXCEPTION 'F9: expected match_reason=exact_date, got %', v_match_reason;
  END IF;

  -- ===== F10: equal authorized_date fallback =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F10 Checking', 'bank', 'f10-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F10 Savings', 'savings', 'f10-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f10-out', 44.00, DATE '2026-08-10', DATE '2026-08-10', 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f10-in', -44.00, DATE '2026-08-11', DATE '2026-08-10', 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id, r.evidence_snapshot->>'match_reason'
    INTO v_recon_id, v_match_reason
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in
    AND r.state = 'candidate';
  IF v_recon_id IS NULL THEN
    RAISE EXCEPTION 'F10: expected candidate, metrics=%', v_metrics;
  END IF;
  IF v_match_reason IS DISTINCT FROM 'equal_authorized_date' THEN
    RAISE EXCEPTION 'F10: expected match_reason=equal_authorized_date, got %', v_match_reason;
  END IF;

  -- ===== F11: ±1 day only → 0 =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F11 Checking', 'bank', 'f11-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F11 Savings', 'savings', 'f11-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f11-out', 66.00, DATE '2026-08-11', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f11-in', -66.00, DATE '2026-08-12', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidate_count(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F11: expected 0 for ±1 day-only, metrics=%', v_metrics;
  END IF;

  -- ===== F12: allowlist + confidence LOW/null → candidate =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F12 Checking', 'bank', 'f12-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F12 Savings', 'savings', 'f12-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f12-out', 12.00, DATE '2026-08-12', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'LOW');
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f12-in', -12.00, DATE '2026-08-12', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', NULL);
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id,
         r.evidence_snapshot->'outgoing'->>'pfc_confidence',
         r.evidence_snapshot->'incoming'->>'pfc_confidence'
    INTO v_recon_id, v_conf_out, v_conf_in
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in
    AND r.state = 'candidate';
  IF v_recon_id IS NULL THEN
    RAISE EXCEPTION 'F12: expected candidate with LOW/null confidence, metrics=%', v_metrics;
  END IF;
  IF v_conf_out IS DISTINCT FROM 'LOW' THEN
    RAISE EXCEPTION 'F12: expected outgoing confidence LOW in evidence, got %', v_conf_out;
  END IF;
  IF v_conf_in IS NOT NULL THEN
    RAISE EXCEPTION 'F12: expected incoming confidence null in evidence, got %', v_conf_in;
  END IF;

  -- ===== F13: non-allowlist PFC both sides → 0 =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F13 Checking', 'bank', 'f13-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F13 Savings', 'savings', 'f13-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f13-out', 13.00, DATE '2026-08-13', NULL, 'USD',
    'v2', 'FOOD_AND_DRINK', 'FOOD_AND_DRINK_GROCERIES', 'HIGH');
  PERFORM pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f13-in', -13.00, DATE '2026-08-13', NULL, 'USD',
    'v2', 'FOOD_AND_DRINK', 'FOOD_AND_DRINK_GROCERIES', 'HIGH');
  v_metrics := pg_temp.reconcile(v_user_id);
  IF pg_temp.active_candidate_count(v_user_id) <> 0 THEN
    RAISE EXCEPTION 'F13: expected 0 for non-allowlist PFC, metrics=%', v_metrics;
  END IF;

  -- ===== F14: amount change → same row invalidated =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F14 Checking', 'bank', 'f14-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F14 Savings', 'savings', 'f14-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f14-out', 140.00, DATE '2026-08-14', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_raw_out := (v_payload->>'raw_id')::uuid;
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f14-in', -140.00, DATE '2026-08-14', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id INTO v_recon_id
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in
    AND r.state = 'candidate';
  IF v_recon_id IS NULL THEN
    RAISE EXCEPTION 'F14: setup candidate missing, metrics=%', v_metrics;
  END IF;
  UPDATE public.plaid_transactions SET amount = 141.00 WHERE id = v_raw_out;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id, r.state, r.invalidated_at
    INTO v_recon_id_2, v_state, v_inv_at
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in;
  IF v_recon_id_2 IS DISTINCT FROM v_recon_id THEN
    RAISE EXCEPTION 'F14: reconciliation id changed';
  END IF;
  IF v_state IS DISTINCT FROM 'invalidated' OR v_inv_at IS NULL THEN
    RAISE EXCEPTION 'F14: expected invalidated with invalidated_at';
  END IF;

  -- ===== F15: removed raw → same row invalidated =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F15 Checking', 'bank', 'f15-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F15 Savings', 'savings', 'f15-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f15-out', 150.00, DATE '2026-08-15', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f15-in', -150.00, DATE '2026-08-15', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_raw_in := (v_payload->>'raw_id')::uuid;
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id INTO v_recon_id
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in
    AND r.state = 'candidate';
  IF v_recon_id IS NULL THEN
    RAISE EXCEPTION 'F15: setup candidate missing, metrics=%', v_metrics;
  END IF;
  UPDATE public.plaid_transactions SET removed_at = now() WHERE id = v_raw_in;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id, r.state, r.invalidated_at
    INTO v_recon_id_2, v_state, v_inv_at
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in;
  IF v_recon_id_2 IS DISTINCT FROM v_recon_id THEN
    RAISE EXCEPTION 'F15: reconciliation id changed';
  END IF;
  IF v_state IS DISTINCT FROM 'invalidated' OR v_inv_at IS NULL THEN
    RAISE EXCEPTION 'F15: expected invalidated with invalidated_at';
  END IF;

  -- ===== F16: candidate → invalidated → candidate (same id) =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F16 Checking', 'bank', 'f16-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F16 Savings', 'savings', 'f16-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f16-out', 160.00, DATE '2026-08-16', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_raw_out := (v_payload->>'raw_id')::uuid;
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f16-in', -160.00, DATE '2026-08-16', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id, r.candidate_detected_at
    INTO v_recon_id, v_detected_at
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in
    AND r.state = 'candidate';
  IF v_recon_id IS NULL THEN
    RAISE EXCEPTION 'F16: initial candidate missing, metrics=%', v_metrics;
  END IF;

  UPDATE public.plaid_transactions SET amount = 161.00 WHERE id = v_raw_out;
  v_metrics := pg_temp.reconcile(v_user_id);
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id
      AND r.state = 'invalidated'
      AND r.invalidated_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'F16: expected same row invalidated, metrics=%', v_metrics;
  END IF;

  UPDATE public.plaid_transactions SET amount = 160.00 WHERE id = v_raw_out;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id, r.state, r.invalidated_at, r.candidate_detected_at
    INTO v_recon_id_2, v_state, v_inv_at, v_detected_at_2
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in;
  IF v_recon_id_2 IS DISTINCT FROM v_recon_id THEN
    RAISE EXCEPTION 'F16: reconciliation id changed on reactivation';
  END IF;
  IF v_state IS DISTINCT FROM 'candidate' OR v_inv_at IS NOT NULL THEN
    RAISE EXCEPTION 'F16: expected reactivated candidate with invalidated_at NULL';
  END IF;
  IF v_detected_at_2 IS DISTINCT FROM v_detected_at THEN
    RAISE EXCEPTION 'F16: candidate_detected_at was not preserved';
  END IF;
  IF coalesce((v_metrics->>'candidates_reactivated')::int, 0) < 1 THEN
    RAISE EXCEPTION 'F16: expected candidates_reactivated>=1, metrics=%', v_metrics;
  END IF;

  -- ===== F17: repeated reconcile → no duplicate row =====
  PERFORM pg_temp.retire_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'F17 Checking', 'bank', 'f17-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'F17 Savings', 'savings', 'f17-sav');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'f17-out', 170.00, DATE '2026-08-17', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'f17-in', -170.00, DATE '2026-08-17', NULL, 'USD',
    'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_metrics := pg_temp.reconcile(v_user_id);
  SELECT r.id INTO v_recon_id
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_id
    AND r.outgoing_projection_id = v_proj_out
    AND r.incoming_projection_id = v_proj_in
    AND r.state = 'candidate';
  IF v_recon_id IS NULL THEN
    RAISE EXCEPTION 'F17: first candidate missing, metrics=%', v_metrics;
  END IF;
  v_metrics := pg_temp.reconcile(v_user_id);
  IF (
    SELECT count(*)::int
    FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = v_user_id
      AND r.outgoing_projection_id = v_proj_out
      AND r.incoming_projection_id = v_proj_in
  ) <> 1 THEN
    RAISE EXCEPTION 'F17: duplicate reconciliation row created';
  END IF;
  IF pg_temp.active_candidate_count(v_user_id) <> 1 THEN
    RAISE EXCEPTION 'F17: expected exactly 1 active candidate after repeat';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state = 'candidate'
  ) THEN
    RAISE EXCEPTION 'F17: stable identity row not preserved';
  END IF;
  IF coalesce((v_metrics->>'candidates_unchanged')::int, 0) < 1 THEN
    RAISE EXCEPTION 'F17: expected candidates_unchanged>=1, metrics=%', v_metrics;
  END IF;

  -- ===== F18: STRUCTURALLY VERIFIED concurrency protections =====
  SELECT pg_get_functiondef(
    'public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)'::regprocedure
  ) INTO v_def;
  IF position('pg_advisory_xact_lock' IN v_def) = 0 THEN
    RAISE EXCEPTION 'F18: missing pg_advisory_xact_lock';
  END IF;
  IF position('872514001' IN v_def) = 0 THEN
    RAISE EXCEPTION 'F18: missing Stage F lock namespace 872514001';
  END IF;
  IF position('for update' IN lower(v_def)) = 0 THEN
    RAISE EXCEPTION 'F18: missing FOR UPDATE on existing reconciliation rows';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.plaid_internal_transfer_reconciliations'::regclass
      AND conname = 'plaid_internal_transfer_reconciliations_pair_unique'
  ) THEN
    RAISE EXCEPTION 'F18: missing stable pair unique constraint';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_itr_active_outgoing_projection_uidx'
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_itr_active_incoming_projection_uidx'
  ) THEN
    RAISE EXCEPTION 'F18: missing partial unique active-leg indexes';
  END IF;

  -- ===== F19: final sweep (also enforced after every reconcile above) =====
  PERFORM pg_temp.assert_ops_unchanged('F19', v_user_id);

  RAISE NOTICE 'STAGE_F_VALIDATION_PASS';
END;
$$;

SELECT 'STAGE_F_VALIDATION_PASS' AS stage_f_validation_result;

ROLLBACK;
