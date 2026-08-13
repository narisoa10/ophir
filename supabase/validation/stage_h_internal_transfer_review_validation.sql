-- =============================================================================
-- Stage H1 validation harness
-- Read-model security + display-safe payload. Does NOT mutate Stage G RPCs.
-- Run AFTER applying 20260814120000_plaid_internal_transfer_review_read_model.sql
-- One transaction; ends with ROLLBACK.
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_user_a uuid := 'f0131412-0000-4000-8000-000000000001';
  v_user_b uuid := 'f0131412-0000-4000-8000-000000000002';
  v_item_a uuid := 'f0131412-0000-4000-8000-000000000010';
  v_item_b uuid := 'f0131412-0000-4000-8000-000000000011';
  v_secret_a uuid := 'f0131412-0000-4000-8000-0000000000aa';
  v_secret_b uuid := 'f0131412-0000-4000-8000-0000000000ab';
  v_identity_a uuid := 'f0131412-0000-4000-8000-0000000000a1';
  v_identity_b uuid := 'f0131412-0000-4000-8000-0000000000a2';

  v_seq int := 1;
  v_acc_out uuid;
  v_acc_in uuid;
  v_acc_b_out uuid;
  v_acc_b_in uuid;
  v_can_out uuid;
  v_can_in uuid;
  v_can_b_out uuid;
  v_can_b_in uuid;

  v_leg_out jsonb;
  v_leg_in jsonb;
  v_leg_b_out jsonb;
  v_leg_b_in jsonb;
  v_recon_a uuid;
  v_recon_b uuid;
  v_recon_confirmed uuid;
  v_recon_invalidated uuid;
  v_recon_reversed uuid;
  v_transfer_id uuid;
  v_missing_account uuid := 'f0131412-0000-4000-8000-00000000dead';

  v_row record;
  v_count int;
  v_payload text;
  v_keys text;
  v_err text;
  v_state text;
  v_before_ops int;
  v_after_ops int;
  v_before_recon int;
  v_after_recon int;
  v_def text;
  v_confirm jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id IN (v_user_a, v_user_b)) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: auth.users';
  END IF;

  CREATE FUNCTION pg_temp.next_id() RETURNS uuid
  LANGUAGE plpgsql AS $fn$
  DECLARE n int; id uuid;
  BEGIN
    n := coalesce(nullif(current_setting('pg_temp.h1_seq', true), '')::int, 1);
    id := ('f0131412-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid;
    PERFORM set_config('pg_temp.h1_seq', (n + 1)::text, true);
    RETURN id;
  END;
  $fn$;
  PERFORM set_config('pg_temp.h1_seq', v_seq::text, true);

  CREATE FUNCTION pg_temp.as_user(p_user_id uuid) RETURNS void
  LANGUAGE plpgsql AS $fn$
  BEGIN
    -- SECURITY DEFINER read RPC uses auth.uid() from JWT claims only.
    PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
    PERFORM set_config(
      'request.jwt.claims',
      json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text,
      true
    );
  END;
  $fn$;

  CREATE FUNCTION pg_temp.clear_auth() RETURNS void
  LANGUAGE plpgsql AS $fn$
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', '', true);
    PERFORM set_config('request.jwt.claims', '', true);
  END;
  $fn$;

  CREATE FUNCTION pg_temp.make_user(
    p_user_id uuid,
    p_identity_id uuid,
    p_email text
  ) RETURNS void
  LANGUAGE plpgsql AS $fn$
  BEGIN
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      p_user_id, 'authenticated', 'authenticated', p_email,
      extensions.crypt('stage-h1-not-used', extensions.gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      now(), now(), '', '', '', ''
    );
    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) VALUES (
      p_identity_id, p_user_id,
      jsonb_build_object('sub', p_user_id::text, 'email', p_email),
      'email', p_user_id::text, now(), now(), now()
    );
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = p_user_id) THEN
      RAISE EXCEPTION 'profile missing for %', p_user_id;
    END IF;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.make_account(
    p_user_id uuid, p_item_id uuid, p_name text, p_plaid_account_id text
  ) RETURNS uuid
  LANGUAGE plpgsql AS $fn$
  DECLARE v_id uuid := pg_temp.next_id();
  BEGIN
    -- LIVE: accounts_type_check + accounts_source_check (source='manual' only).
    -- Plaid identity is NOT accounts.source; it lives in plaid_* columns.
    -- Canonical checking fixture: type=bank, plaid_type=depository, plaid_subtype=checking.
    INSERT INTO public.accounts (
      id, user_id, name, type, source, currency_code,
      initial_balance, icon_key, color_key, sort_order, is_archived,
      plaid_item_id, plaid_account_id, plaid_type, plaid_subtype, mask
    ) VALUES (
      v_id, p_user_id, p_name, 'bank', 'manual', 'USD',
      0, 'bank', 'blue', 0, false,
      p_item_id, p_plaid_account_id, 'depository', 'checking', '1234'
    );
    RETURN v_id;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.make_leg(
    p_user_id uuid, p_item_id uuid, p_account_id uuid,
    p_txn_id text, p_amount numeric, p_date date
  ) RETURNS jsonb
  LANGUAGE plpgsql AS $fn$
  DECLARE
    v_raw_id uuid := pg_temp.next_id();
    v_op_id uuid := pg_temp.next_id();
    v_proj_id uuid := pg_temp.next_id();
    v_plaid_account_id text;
  BEGIN
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
      p_txn_id, false, p_date, p_date, p_amount,
      'USD', 'h1-' || p_txn_id,
      'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH'
    );

    INSERT INTO public.operations (
      id, user_id, from_account_id, to_account_id, type, amount,
      currency_code, occurred_at, source, category_id, archived_at,
      category_overridden, recurrence, is_recurring, note
    ) VALUES (
      v_op_id, p_user_id, p_account_id, null,
      CASE WHEN p_amount > 0 THEN 'expense' ELSE 'income' END,
      abs(p_amount), 'USD', p_date, 'plaid', null, null,
      false, 'none', false, 'leg-' || p_txn_id
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

  PERFORM pg_temp.make_user(
    v_user_a, v_identity_a, 'stage-h1-a-' || v_user_a::text || '@ophir.invalid');
  PERFORM pg_temp.make_user(
    v_user_b, v_identity_b, 'stage-h1-b-' || v_user_b::text || '@ophir.invalid');

  INSERT INTO public.plaid_items (
    id, user_id, plaid_environment, plaid_item_id, access_token_secret_id
  ) VALUES
    (v_item_a, v_user_a, 'sandbox', 'h1-item-a', v_secret_a),
    (v_item_b, v_user_b, 'sandbox', 'h1-item-b', v_secret_b);

  v_acc_out := pg_temp.make_account(v_user_a, v_item_a, 'Checking A', 'acc-a-out');
  v_acc_in := pg_temp.make_account(v_user_a, v_item_a, 'Savings A', 'acc-a-in');
  v_can_out := pg_temp.next_id();
  v_can_in := pg_temp.next_id();
  INSERT INTO public.plaid_canonical_financial_accounts(id, user_id)
  VALUES (v_can_out, v_user_a), (v_can_in, v_user_a);
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin
  ) VALUES
    (v_user_a, v_can_out, v_acc_out, 'authoritative', 'user_confirmed'),
    (v_user_a, v_can_in, v_acc_in, 'authoritative', 'user_confirmed');

  v_leg_out := pg_temp.make_leg(
    v_user_a, v_item_a, v_acc_out, 'h1-a-out', 100.00, DATE '2026-08-14');
  v_leg_in := pg_temp.make_leg(
    v_user_a, v_item_a, v_acc_in, 'h1-a-in', -100.00, DATE '2026-08-14');
  -- inbound PFC allowlist
  UPDATE public.plaid_transactions
  SET personal_finance_category_detailed = 'TRANSFER_IN_ACCOUNT_TRANSFER',
      personal_finance_category_primary = 'TRANSFER_IN'
  WHERE id = (v_leg_in->>'raw_id')::uuid;

  PERFORM public.plaid_reconcile_internal_transfer_candidates_for_user(v_user_a);
  SELECT r.id INTO v_recon_a
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_a
    AND r.outgoing_projection_id = (v_leg_out->>'proj_id')::uuid
    AND r.incoming_projection_id = (v_leg_in->>'proj_id')::uuid
    AND r.state = 'candidate';
  IF v_recon_a IS NULL THEN
    RAISE EXCEPTION 'H1 setup: candidate A missing';
  END IF;

  -- User B foreign candidate
  v_acc_b_out := pg_temp.make_account(v_user_b, v_item_b, 'Checking B', 'acc-b-out');
  v_acc_b_in := pg_temp.make_account(v_user_b, v_item_b, 'Savings B', 'acc-b-in');
  v_can_b_out := pg_temp.next_id();
  v_can_b_in := pg_temp.next_id();
  INSERT INTO public.plaid_canonical_financial_accounts(id, user_id)
  VALUES (v_can_b_out, v_user_b), (v_can_b_in, v_user_b);
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin
  ) VALUES
    (v_user_b, v_can_b_out, v_acc_b_out, 'authoritative', 'user_confirmed'),
    (v_user_b, v_can_b_in, v_acc_b_in, 'authoritative', 'user_confirmed');
  v_leg_b_out := pg_temp.make_leg(
    v_user_b, v_item_b, v_acc_b_out, 'h1-b-out', 55.00, DATE '2026-08-14');
  v_leg_b_in := pg_temp.make_leg(
    v_user_b, v_item_b, v_acc_b_in, 'h1-b-in', -55.00, DATE '2026-08-14');
  UPDATE public.plaid_transactions
  SET personal_finance_category_detailed = 'TRANSFER_IN_ACCOUNT_TRANSFER',
      personal_finance_category_primary = 'TRANSFER_IN'
  WHERE id = (v_leg_b_in->>'raw_id')::uuid;
  PERFORM public.plaid_reconcile_internal_transfer_candidates_for_user(v_user_b);
  SELECT r.id INTO v_recon_b
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_b AND r.state = 'candidate'
  LIMIT 1;
  IF v_recon_b IS NULL THEN
    RAISE EXCEPTION 'H1 setup: candidate B missing';
  END IF;

  -- =========================================================================
  -- H3: no auth rejected
  -- =========================================================================
  PERFORM pg_temp.clear_auth();
  BEGIN
    PERFORM * FROM public.plaid_list_internal_transfer_review_items();
    RAISE EXCEPTION 'H3: expected not_authenticated failure';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF position('not_authenticated' IN v_err) = 0 THEN
        RAISE EXCEPTION 'H3: unexpected error %', v_err;
      END IF;
  END;

  -- =========================================================================
  -- H1: own candidate visible
  -- =========================================================================
  PERFORM pg_temp.as_user(v_user_a);
  SELECT count(*)::int INTO v_count
  FROM public.plaid_list_internal_transfer_review_items(
    ARRAY['candidate']::text[]
  );
  IF v_count < 1 THEN
    RAISE EXCEPTION 'H1: own candidate not visible';
  END IF;

  SELECT * INTO v_row
  FROM public.plaid_list_internal_transfer_review_items(ARRAY['candidate']::text[])
  WHERE reconciliation_id = v_recon_a;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'H1: expected reconciliation %', v_recon_a;
  END IF;
  IF v_row.state IS DISTINCT FROM 'candidate' THEN
    RAISE EXCEPTION 'H1: state=%', v_row.state;
  END IF;

  -- =========================================================================
  -- H2: foreign candidate not visible
  -- =========================================================================
  IF EXISTS (
    SELECT 1
    FROM public.plaid_list_internal_transfer_review_items(ARRAY['candidate']::text[])
    WHERE reconciliation_id = v_recon_b
  ) THEN
    RAISE EXCEPTION 'H2: foreign candidate leaked';
  END IF;

  -- =========================================================================
  -- H4/H5: safe fields present; forbidden keys absent
  -- =========================================================================
  v_payload := to_jsonb(v_row)::text;
  IF v_row.reconciliation_id IS NULL
     OR v_row.amount IS DISTINCT FROM 100.00
     OR v_row.currency_code IS DISTINCT FROM 'USD'
     OR v_row.outgoing_date IS NULL
     OR v_row.incoming_date IS NULL
     OR v_row.outgoing_account IS NULL
     OR v_row.incoming_account IS NULL
     OR v_row.outgoing_operation IS NULL
     OR v_row.incoming_operation IS NULL
  THEN
    RAISE EXCEPTION 'H4: missing expected safe fields %', v_payload;
  END IF;

  IF v_payload ILIKE '%projection_id%'
     OR v_payload ILIKE '%canonical_account%'
     OR v_payload ILIKE '%evidence_snapshot%'
     OR v_payload ILIKE '%confirmed_snapshot%'
     OR v_payload ILIKE '%personal_finance_category%'
     OR v_payload ILIKE '%plaid_item_id%'
     OR v_payload ILIKE '%access_token%'
  THEN
    RAISE EXCEPTION 'H5: forbidden internal content in payload %', v_payload;
  END IF;

  -- structural key denylist on jsonb object keys
  SELECT string_agg(k, ',') INTO v_keys
  FROM jsonb_object_keys(to_jsonb(v_row)) AS k;
  IF v_keys ILIKE '%projection%'
     OR v_keys ILIKE '%canonical%'
     OR v_keys ILIKE '%evidence%'
     OR v_keys ILIKE '%snapshot%'
  THEN
    RAISE EXCEPTION 'H5: forbidden top-level keys %', v_keys;
  END IF;

  -- =========================================================================
  -- H8 candidate included (default)
  -- =========================================================================
  SELECT count(*)::int INTO v_count
  FROM public.plaid_list_internal_transfer_review_items()
  WHERE state = 'candidate';
  IF v_count < 1 THEN
    RAISE EXCEPTION 'H8: default list missing candidates';
  END IF;

  -- Prepare confirmed / invalidated / reversed rows for filter tests
  PERFORM pg_temp.clear_auth();
  v_leg_out := pg_temp.make_leg(
    v_user_a, v_item_a, v_acc_out, 'h1-a2-out', 200.00, DATE '2026-08-15');
  v_leg_in := pg_temp.make_leg(
    v_user_a, v_item_a, v_acc_in, 'h1-a2-in', -200.00, DATE '2026-08-15');
  UPDATE public.plaid_transactions
  SET personal_finance_category_detailed = 'TRANSFER_IN_ACCOUNT_TRANSFER',
      personal_finance_category_primary = 'TRANSFER_IN'
  WHERE id = (v_leg_in->>'raw_id')::uuid;
  PERFORM public.plaid_reconcile_internal_transfer_candidates_for_user(v_user_a);
  SELECT r.id INTO v_recon_confirmed
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_a
    AND r.outgoing_projection_id = (v_leg_out->>'proj_id')::uuid
    AND r.state = 'candidate';
  IF v_recon_confirmed IS NULL THEN
    RAISE EXCEPTION 'setup confirmed candidate missing';
  END IF;

  v_confirm := public.plaid_confirm_internal_transfer_candidate(
    v_user_a, v_recon_confirmed);
  IF coalesce(v_confirm->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'setup confirm failed %', v_confirm;
  END IF;
  v_transfer_id := (v_confirm->>'transfer_operation_id')::uuid;

  -- Mark confirmed inconsistent for H10
  UPDATE public.plaid_internal_transfer_reconciliations
  SET inconsistent_at = now(),
      inconsistency_code = 'amount_mismatch'
  WHERE id = v_recon_confirmed;

  -- invalidated row (lifecycle-legal): soft-remove raw so pair is ineligible,
  -- then reconcile. Do NOT direct-UPDATE state while pair stays eligible —
  -- a later detector reconcile (H7 setup) would reactivate candidate↔invalidated.
  v_leg_out := pg_temp.make_leg(
    v_user_a, v_item_a, v_acc_out, 'h1-a3-out', 300.00, DATE '2026-08-16');
  v_leg_in := pg_temp.make_leg(
    v_user_a, v_item_a, v_acc_in, 'h1-a3-in', -300.00, DATE '2026-08-16');
  UPDATE public.plaid_transactions
  SET personal_finance_category_detailed = 'TRANSFER_IN_ACCOUNT_TRANSFER',
      personal_finance_category_primary = 'TRANSFER_IN'
  WHERE id = (v_leg_in->>'raw_id')::uuid;
  PERFORM public.plaid_reconcile_internal_transfer_candidates_for_user(v_user_a);
  SELECT r.id INTO v_recon_invalidated
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_a
    AND r.outgoing_projection_id = (v_leg_out->>'proj_id')::uuid
    AND r.state = 'candidate';
  IF v_recon_invalidated IS NULL THEN
    RAISE EXCEPTION 'setup invalidated candidate missing';
  END IF;
  UPDATE public.plaid_transactions
  SET removed_at = coalesce(removed_at, now())
  WHERE id = (v_leg_in->>'raw_id')::uuid
    AND removed_at IS NULL;
  PERFORM public.plaid_reconcile_internal_transfer_candidates_for_user(v_user_a);
  SELECT r.state INTO v_state
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_invalidated;
  IF v_state IS DISTINCT FROM 'invalidated' THEN
    RAISE EXCEPTION 'setup H6: expected invalidated, got %', v_state;
  END IF;

  -- reversed row via reverse RPC on a fresh confirm
  v_leg_out := pg_temp.make_leg(
    v_user_a, v_item_a, v_acc_out, 'h1-a4-out', 400.00, DATE '2026-08-17');
  v_leg_in := pg_temp.make_leg(
    v_user_a, v_item_a, v_acc_in, 'h1-a4-in', -400.00, DATE '2026-08-17');
  UPDATE public.plaid_transactions
  SET personal_finance_category_detailed = 'TRANSFER_IN_ACCOUNT_TRANSFER',
      personal_finance_category_primary = 'TRANSFER_IN'
  WHERE id = (v_leg_in->>'raw_id')::uuid;
  PERFORM public.plaid_reconcile_internal_transfer_candidates_for_user(v_user_a);
  SELECT r.id INTO v_recon_reversed
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.user_id = v_user_a
    AND r.outgoing_projection_id = (v_leg_out->>'proj_id')::uuid
    AND r.state = 'candidate';
  IF v_recon_reversed IS NULL THEN
    RAISE EXCEPTION 'setup reversed candidate missing';
  END IF;
  PERFORM public.plaid_confirm_internal_transfer_candidate(v_user_a, v_recon_reversed);
  PERFORM public.plaid_reverse_internal_transfer_resolution(v_user_a, v_recon_reversed);

  -- Re-confirm H6 stayed invalidated after H7 setup reconcile (ineligible raw).
  SELECT r.state INTO v_state
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_invalidated;
  IF v_state IS DISTINCT FROM 'invalidated' THEN
    RAISE EXCEPTION 'H6 fixture: expected invalidated before assertion, got %', v_state;
  END IF;

  SELECT r.state INTO v_state
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_reversed;
  IF v_state IS DISTINCT FROM 'reversed' THEN
    RAISE EXCEPTION 'H7 fixture: expected reversed before assertion, got %', v_state;
  END IF;

  -- =========================================================================
  -- H6/H7: invalidated/reversed excluded by default
  -- =========================================================================
  PERFORM pg_temp.as_user(v_user_a);
  IF EXISTS (
    SELECT 1 FROM public.plaid_list_internal_transfer_review_items()
    WHERE reconciliation_id = v_recon_invalidated
  ) THEN
    RAISE EXCEPTION 'H6: invalidated included by default';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.plaid_list_internal_transfer_review_items()
    WHERE reconciliation_id = v_recon_reversed
  ) THEN
    RAISE EXCEPTION 'H7: reversed included by default';
  END IF;

  -- =========================================================================
  -- H9: confirmed included when requested / default
  -- =========================================================================
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_list_internal_transfer_review_items()
    WHERE reconciliation_id = v_recon_confirmed AND state = 'confirmed'
  ) THEN
    RAISE EXCEPTION 'H9: confirmed missing from default';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.plaid_list_internal_transfer_review_items(
      ARRAY['candidate']::text[]
    )
    WHERE reconciliation_id = v_recon_confirmed
  ) THEN
    RAISE EXCEPTION 'H9: confirmed leaked into candidate-only filter';
  END IF;

  -- =========================================================================
  -- H10: inconsistent confirmed exposes only safe consistency fields
  -- =========================================================================
  SELECT * INTO v_row
  FROM public.plaid_list_internal_transfer_review_items(ARRAY['confirmed']::text[])
  WHERE reconciliation_id = v_recon_confirmed;
  IF v_row.is_inconsistent IS NOT TRUE
     OR v_row.inconsistency_code IS DISTINCT FROM 'amount_mismatch'
  THEN
    RAISE EXCEPTION 'H10: inconsistency fields wrong';
  END IF;
  v_payload := to_jsonb(v_row)::text;
  IF v_payload ILIKE '%confirmed_snapshot%' OR v_payload ILIKE '%evidence_snapshot%' THEN
    RAISE EXCEPTION 'H10: snapshot leaked';
  END IF;

  -- =========================================================================
  -- H11: account missing/fallback deterministic
  -- =========================================================================
  UPDATE public.plaid_internal_transfer_reconciliations
  SET confirmed_snapshot = jsonb_set(
    confirmed_snapshot,
    '{outgoing_account_id}',
    to_jsonb(v_missing_account::text),
    true
  )
  WHERE id = v_recon_confirmed;
  SELECT * INTO v_row
  FROM public.plaid_list_internal_transfer_review_items(ARRAY['confirmed']::text[])
  WHERE reconciliation_id = v_recon_confirmed;
  IF (v_row.outgoing_account->>'available')::boolean IS NOT FALSE THEN
    RAISE EXCEPTION 'H11: expected available=false for missing account';
  END IF;
  IF v_row.outgoing_account->>'display_name' IS NOT NULL THEN
    RAISE EXCEPTION 'H11: expected null display_name';
  END IF;
  IF (v_row.outgoing_account->>'id')::uuid IS DISTINCT FROM v_missing_account THEN
    RAISE EXCEPTION 'H11: expected fallback id preserved';
  END IF;

  -- =========================================================================
  -- H12: unsupported state rejected
  -- =========================================================================
  BEGIN
    PERFORM * FROM public.plaid_list_internal_transfer_review_items(
      ARRAY['reversed']::text[]
    );
    RAISE EXCEPTION 'H12: expected invalid_input for reversed filter';
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF position('invalid_input' IN v_err) = 0 THEN
        RAISE EXCEPTION 'H12: unexpected %', v_err;
      END IF;
  END;

  -- =========================================================================
  -- H13: repeat read idempotent
  -- =========================================================================
  SELECT count(*)::int INTO v_before_recon
  FROM public.plaid_list_internal_transfer_review_items();
  SELECT count(*)::int INTO v_after_recon
  FROM public.plaid_list_internal_transfer_review_items();
  IF v_before_recon IS DISTINCT FROM v_after_recon THEN
    RAISE EXCEPTION 'H13: non-idempotent counts';
  END IF;

  -- =========================================================================
  -- H14: grants/authenticated contract
  -- =========================================================================
  SELECT pg_get_functiondef(
    'public.plaid_list_internal_transfer_review_items(text[])'::regprocedure
  ) INTO v_def;
  IF v_def IS NULL OR position('auth.uid()' IN v_def) = 0 THEN
    RAISE EXCEPTION 'H14: auth.uid fencing missing';
  END IF;
  IF NOT has_function_privilege(
    'authenticated',
    'public.plaid_list_internal_transfer_review_items(text[])',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'H14: authenticated missing EXECUTE';
  END IF;
  IF has_function_privilege(
    'anon',
    'public.plaid_list_internal_transfer_review_items(text[])',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'H14: anon must not EXECUTE';
  END IF;

  -- =========================================================================
  -- H15: read RPC does not mutate ops/reconciliations
  -- =========================================================================
  SELECT count(*)::int INTO v_before_ops FROM public.operations WHERE user_id = v_user_a;
  SELECT count(*)::int INTO v_before_recon
  FROM public.plaid_internal_transfer_reconciliations WHERE user_id = v_user_a;
  PERFORM * FROM public.plaid_list_internal_transfer_review_items();
  SELECT count(*)::int INTO v_after_ops FROM public.operations WHERE user_id = v_user_a;
  SELECT count(*)::int INTO v_after_recon
  FROM public.plaid_internal_transfer_reconciliations WHERE user_id = v_user_a;
  IF v_before_ops IS DISTINCT FROM v_after_ops
     OR v_before_recon IS DISTINCT FROM v_after_recon
  THEN
    RAISE EXCEPTION 'H15: read RPC mutated rows';
  END IF;

  RAISE NOTICE 'STAGE_H1_VALIDATION_PASS';
END;
$$;

SELECT 'STAGE_H1_VALIDATION_PASS' AS stage_h1_validation_result;

ROLLBACK;
