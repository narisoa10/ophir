-- =============================================================================
-- Stage G validation harness (G1–G30)
-- Temporary / non-migration SQL. Does not change production schema or RPCs.
-- Run as: postgres against linked Supabase DB (AFTER Stage G migration applied).
-- One transaction; ends with ROLLBACK. No leftover fixture data.
-- Do NOT run this from CI/agents unless explicitly requested.
-- No Plaid API / workers / Edge Functions / production DDL changes.
-- Fixture namespace mirrors Stage F (f + migration stamp); 'g' is not valid hex.
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_user_id uuid := 'f0132000-0000-4000-8000-000000000001';
  v_item_id uuid := 'f0132000-0000-4000-8000-000000000010';
  v_secret_id uuid := 'f0132000-0000-4000-8000-0000000000ff';
  v_identity_id uuid := 'f0132000-0000-4000-8000-0000000000aa';
  v_lease_token uuid := 'f0132000-0000-4000-8000-0000000000ee';
  v_manual_op_id uuid := 'f0132000-0000-4000-8000-0000000000b1';
  v_manual_acc_id uuid := 'f0132000-0000-4000-8000-0000000000b0';

  v_seq int := 256;

  v_metrics jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_sync jsonb;
  v_def text;
  v_snap jsonb;
  v_snap2 jsonb;
  v_manual_before jsonb;
  v_manual_after jsonb;

  v_acc_a uuid;
  v_acc_b uuid;
  v_acc_c uuid;
  v_can_a uuid;
  v_can_b uuid;
  v_can_c uuid;

  v_raw_out uuid;
  v_raw_in uuid;
  v_op_out uuid;
  v_op_in uuid;
  v_op_kept uuid;
  v_proj_out uuid;
  v_proj_in uuid;
  v_transfer_id uuid;
  v_transfer_id_2 uuid;
  v_recon_id uuid;
  v_recon_id_2 uuid;
  v_state text;
  v_code text;
  v_inconsistent_at timestamptz;
  v_confirmed_at timestamptz;
  v_reversed_at timestamptz;
  v_evidence jsonb;
  v_archived_out timestamptz;
  v_archived_in timestamptz;
  v_amt_out numeric;
  v_amt_in numeric;
  v_synth_amt numeric;
  v_synth_type text;
  v_synth_source text;
  v_synth_from uuid;
  v_synth_to uuid;
  v_synth_cat text;
  v_synth_arch timestamptz;
  v_count int;
  v_err text;
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

  CREATE FUNCTION pg_temp.next_id()
  RETURNS uuid
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    n int;
  BEGIN
    n := current_setting('pg_temp.stage_g_seq', true)::int;
    IF n IS NULL THEN
      n := 256;
    END IF;
    n := n + 1;
    PERFORM set_config('pg_temp.stage_g_seq', n::text, true);
    RETURN ('f0132000-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid;
  END;
  $fn$;

  PERFORM set_config('pg_temp.stage_g_seq', v_seq::text, true);

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

  CREATE FUNCTION pg_temp.retire_nonterminal_raw(p_user_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  AS $fn$
  BEGIN
    UPDATE public.plaid_internal_transfer_reconciliations r
    SET
      state = 'invalidated',
      invalidated_at = coalesce(r.invalidated_at, now()),
      updated_at = now()
    WHERE r.user_id = p_user_id
      AND r.state = 'candidate';

    UPDATE public.plaid_transactions t
    SET removed_at = coalesce(t.removed_at, now())
    WHERE t.user_id = p_user_id
      AND t.removed_at IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.plaid_transaction_operation_projections p
        JOIN public.plaid_internal_transfer_reconciliations r
          ON r.user_id = p.user_id
         AND r.state IN ('confirmed', 'reversed')
         AND (
              r.outgoing_projection_id = p.id
           OR r.incoming_projection_id = p.id
         )
        WHERE p.user_id = t.user_id
          AND p.plaid_item_id = t.plaid_item_id
          AND p.plaid_transaction_id = t.transaction_id
      );
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
    v_id uuid := pg_temp.next_id();
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
    v_id uuid := pg_temp.next_id();
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
    v_raw_id uuid := pg_temp.next_id();
    v_op_id uuid := pg_temp.next_id();
    v_proj_id uuid := pg_temp.next_id();
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
      p_iso, 'stage-g-fixture-' || p_txn_id,
      p_pfc_version, p_pfc_primary, p_pfc_detailed, p_pfc_confidence
    );

    INSERT INTO public.operations (
      id, user_id, from_account_id, to_account_id, type, amount,
      currency_code, occurred_at, source, category_id, archived_at,
      category_overridden, recurrence, is_recurring, note
    ) VALUES (
      v_op_id, p_user_id, p_account_id, null, v_op_type, abs(p_amount),
      'USD', p_date, 'plaid', null, null,
      false, 'none', false, null
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

  CREATE FUNCTION pg_temp.ensure_projection_lease(
    p_user_id uuid,
    p_item_id uuid,
    p_lease_token uuid
  ) RETURNS void
  LANGUAGE plpgsql
  AS $fn$
  BEGIN
    INSERT INTO public.plaid_transaction_projection_jobs (
      plaid_item_id, user_id, status, requested_at, next_attempt_at,
      attempt_count, rerun_requested, lease_token, lease_expires_at, last_error_code
    ) VALUES (
      p_item_id, p_user_id, 'processing', now(), now(),
      1, false, p_lease_token, now() + interval '1 hour', null
    )
    ON CONFLICT (plaid_item_id) DO UPDATE
    SET
      user_id = excluded.user_id,
      status = 'processing',
      lease_token = excluded.lease_token,
      lease_expires_at = excluded.lease_expires_at,
      updated_at = now(),
      last_error_code = null;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.run_source_sync(
    p_user_id uuid,
    p_item_id uuid,
    p_lease_token uuid
  ) RETURNS jsonb
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    m jsonb;
  BEGIN
    PERFORM pg_temp.ensure_projection_lease(p_user_id, p_item_id, p_lease_token);
    m := public.plaid_sync_materialized_transaction_operations(
      p_user_id, p_item_id, p_lease_token, 250
    );
    RETURN m;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.setup_chk_sav_pair(
    p_user_id uuid,
    p_item_id uuid,
    p_tag text,
    p_amount numeric,
    p_date date
  ) RETURNS jsonb
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    v_acc_a uuid;
    v_acc_b uuid;
    v_can_a uuid;
    v_can_b uuid;
    v_out jsonb;
    v_in jsonb;
  BEGIN
    PERFORM pg_temp.retire_nonterminal_raw(p_user_id);
    v_acc_a := pg_temp.make_account(p_user_id, p_item_id, p_tag || ' Checking', 'bank', p_tag || '-chk');
    v_acc_b := pg_temp.make_account(p_user_id, p_item_id, p_tag || ' Savings', 'savings', p_tag || '-sav');
    v_can_a := pg_temp.make_canonical(p_user_id);
    v_can_b := pg_temp.make_canonical(p_user_id);
    PERFORM pg_temp.link_member(p_user_id, v_can_a, v_acc_a, 'authoritative');
    PERFORM pg_temp.link_member(p_user_id, v_can_b, v_acc_b, 'authoritative');
    v_out := pg_temp.make_leg(
      p_user_id, p_item_id, v_acc_a, p_tag || '-out', p_amount, p_date, NULL, 'USD',
      'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'HIGH');
    v_in := pg_temp.make_leg(
      p_user_id, p_item_id, v_acc_b, p_tag || '-in', -p_amount, p_date, NULL, 'USD',
      'v2', 'TRANSFER_IN', 'TRANSFER_IN_ACCOUNT_TRANSFER', 'HIGH');
    RETURN jsonb_build_object(
      'acc_a', v_acc_a,
      'acc_b', v_acc_b,
      'can_a', v_can_a,
      'can_b', v_can_b,
      'raw_out', v_out->>'raw_id',
      'raw_in', v_in->>'raw_id',
      'op_out', v_out->>'op_id',
      'op_in', v_in->>'op_id',
      'proj_out', v_out->>'proj_id',
      'proj_in', v_in->>'proj_id'
    );
  END;
  $fn$;

  CREATE FUNCTION pg_temp.detect_and_get_recon(
    p_user_id uuid,
    p_proj_out uuid,
    p_proj_in uuid
  ) RETURNS uuid
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    v_id uuid;
    m jsonb;
  BEGIN
    m := public.plaid_reconcile_internal_transfer_candidates_for_user(p_user_id);
    SELECT r.id INTO v_id
    FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = p_user_id
      AND r.outgoing_projection_id = p_proj_out
      AND r.incoming_projection_id = p_proj_in
      AND r.state = 'candidate';
    IF v_id IS NULL THEN
      RAISE EXCEPTION 'detect_and_get_recon: missing candidate metrics=%', m;
    END IF;
    RETURN v_id;
  END;
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
    'stage-g-validation-' || v_user_id::text || '@ophir.invalid',
    extensions.crypt('stage-g-validation-not-used', extensions.gen_salt('bf')),
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
      'email', 'stage-g-validation-' || v_user_id::text || '@ophir.invalid'
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
    'stage-g-item-' || v_user_id::text,
    v_secret_id
  );

  -- Manual account + operation for G30 isolation (registered before Stage G mutations)
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived
  ) VALUES (
    v_manual_acc_id, v_user_id, 'G30 Manual Cash', 'cash', 'USD',
    0, 'cash', 'green', 0, false
  );

  INSERT INTO public.operations (
    id, user_id, from_account_id, to_account_id, type, amount,
    currency_code, occurred_at, source, category_id, archived_at,
    category_overridden, recurrence, is_recurring, note
  ) VALUES (
    v_manual_op_id, v_user_id, v_manual_acc_id, null, 'expense', 12.34,
    'USD', DATE '2026-01-15', 'manual', 'expenseHousingRent', null,
    false, 'none', false, 'stage-g-manual-sentinel'
  );

  SELECT to_jsonb(o) INTO v_manual_before
  FROM public.operations o
  WHERE o.id = v_manual_op_id;

  PERFORM pg_temp.register_ops(v_user_id);

  -- =========================================================================
  -- G1: confirm checking → savings
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g1', 100.00, DATE '2026-08-01');
  v_acc_a := (v_payload->>'acc_a')::uuid;
  v_acc_b := (v_payload->>'acc_b')::uuid;
  v_raw_out := (v_payload->>'raw_out')::uuid;
  v_raw_in := (v_payload->>'raw_in')::uuid;
  v_op_out := (v_payload->>'op_out')::uuid;
  v_op_in := (v_payload->>'op_in')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G1: expected status=confirmed, got %', v_result;
  END IF;
  v_transfer_id := (v_result->>'transfer_operation_id')::uuid;
  IF v_transfer_id IS NULL THEN
    RAISE EXCEPTION 'G1: missing transfer_operation_id';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id
      AND r.state = 'confirmed'
      AND r.transfer_operation_id = v_transfer_id
      AND r.confirmed_at IS NOT NULL
      AND r.confirmed_snapshot IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'G1: reconciliation not confirmed';
  END IF;

  -- =========================================================================
  -- G2: confirm checking → credit-card payment
  -- =========================================================================
  PERFORM pg_temp.retire_nonterminal_raw(v_user_id);
  v_acc_a := pg_temp.make_account(v_user_id, v_item_id, 'G2 Checking', 'bank', 'g2-chk');
  v_acc_b := pg_temp.make_account(v_user_id, v_item_id, 'G2 Credit', 'credit_card', 'g2-cc');
  v_can_a := pg_temp.make_canonical(v_user_id);
  v_can_b := pg_temp.make_canonical(v_user_id);
  PERFORM pg_temp.link_member(v_user_id, v_can_a, v_acc_a, 'authoritative');
  PERFORM pg_temp.link_member(v_user_id, v_can_b, v_acc_b, 'authoritative');
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_a, 'g2-out', 250.00, DATE '2026-08-02', NULL, 'USD',
    'v2', 'TRANSFER_OUT', 'TRANSFER_OUT_ACCOUNT_TRANSFER', 'VERY_HIGH');
  v_op_out := (v_payload->>'op_id')::uuid;
  v_proj_out := (v_payload->>'proj_id')::uuid;
  v_payload := pg_temp.make_leg(
    v_user_id, v_item_id, v_acc_b, 'g2-in', -250.00, DATE '2026-08-02', NULL, 'USD',
    'v2', 'LOAN_PAYMENTS', 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT', 'HIGH');
  v_op_in := (v_payload->>'op_id')::uuid;
  v_proj_in := (v_payload->>'proj_id')::uuid;
  v_recon_id_2 := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id_2);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G2: expected confirmed CC payment, got %', v_result;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.operations o
    WHERE o.id = (v_result->>'transfer_operation_id')::uuid
      AND o.type = 'transfer'
      AND o.from_account_id = v_acc_a
      AND o.to_account_id = v_acc_b
      AND o.amount = 250.00
  ) THEN
    RAISE EXCEPTION 'G2: synthetic CC transfer fields wrong';
  END IF;

  -- =========================================================================
  -- G3: stale candidate rejected / no synthetic
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g3', 130.00, DATE '2026-08-03');
  v_raw_out := (v_payload->>'raw_out')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  UPDATE public.plaid_transactions SET amount = 131.00 WHERE id = v_raw_out;
  SELECT count(*)::int INTO v_count
  FROM public.operations o
  WHERE o.user_id = v_user_id AND o.source = 'plaid_internal_transfer';
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'rejected' THEN
    RAISE EXCEPTION 'G3: expected rejected, got %', v_result;
  END IF;
  IF coalesce(v_result->>'reason', '') <> 'stale_candidate' THEN
    RAISE EXCEPTION 'G3: expected reason=stale_candidate, got %', v_result;
  END IF;
  IF (
    SELECT count(*)::int
    FROM public.operations o
    WHERE o.user_id = v_user_id AND o.source = 'plaid_internal_transfer'
  ) <> v_count THEN
    RAISE EXCEPTION 'G3: synthetic created on rejected confirm';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state = 'invalidated' AND r.transfer_operation_id IS NULL
  ) THEN
    RAISE EXCEPTION 'G3: stale candidate not invalidated';
  END IF;

  -- =========================================================================
  -- G4: repeated confirm idempotent / same synthetic
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g4', 140.00, DATE '2026-08-04');
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G4: first confirm failed %', v_result;
  END IF;
  v_transfer_id := (v_result->>'transfer_operation_id')::uuid;
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'already_confirmed' THEN
    RAISE EXCEPTION 'G4: expected already_confirmed, got %', v_result;
  END IF;
  IF (v_result->>'transfer_operation_id')::uuid IS DISTINCT FROM v_transfer_id THEN
    RAISE EXCEPTION 'G4: transfer_operation_id changed on repeat';
  END IF;
  IF (
    SELECT count(*)::int
    FROM public.operations o
    WHERE o.user_id = v_user_id
      AND o.source = 'plaid_internal_transfer'
      AND o.id = v_transfer_id
  ) <> 1 THEN
    RAISE EXCEPTION 'G4: expected exactly one synthetic row for transfer';
  END IF;

  -- =========================================================================
  -- G5: one reconciliation → exactly one synthetic
  -- =========================================================================
  IF (
    SELECT count(*)::int
    FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id
      AND r.transfer_operation_id = v_transfer_id
      AND r.state = 'confirmed'
  ) <> 1 THEN
    RAISE EXCEPTION 'G5: reconciliation↔synthetic mapping broken';
  END IF;
  IF (
    SELECT count(*)::int
    FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = v_user_id
      AND r.transfer_operation_id = v_transfer_id
  ) <> 1 THEN
    RAISE EXCEPTION 'G5: transfer_operation_id not unique to one reconciliation';
  END IF;

  -- =========================================================================
  -- G6: both legs archived on confirm
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g6', 160.00, DATE '2026-08-06');
  v_op_out := (v_payload->>'op_out')::uuid;
  v_op_in := (v_payload->>'op_in')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G6: confirm failed %', v_result;
  END IF;
  SELECT o.archived_at INTO v_archived_out FROM public.operations o WHERE o.id = v_op_out;
  SELECT o.archived_at INTO v_archived_in FROM public.operations o WHERE o.id = v_op_in;
  IF v_archived_out IS NULL OR v_archived_in IS NULL THEN
    RAISE EXCEPTION 'G6: both legs must be archived after confirm';
  END IF;

  -- =========================================================================
  -- G7: synthetic fields exact
  -- =========================================================================
  v_transfer_id := (v_result->>'transfer_operation_id')::uuid;
  v_acc_a := (v_payload->>'acc_a')::uuid;
  v_acc_b := (v_payload->>'acc_b')::uuid;
  SELECT
    o.type, o.source, o.amount, o.from_account_id, o.to_account_id,
    o.category_id, o.archived_at
  INTO
    v_synth_type, v_synth_source, v_synth_amt, v_synth_from, v_synth_to,
    v_synth_cat, v_synth_arch
  FROM public.operations o
  WHERE o.id = v_transfer_id;

  IF v_synth_type IS DISTINCT FROM 'transfer'
     OR v_synth_source IS DISTINCT FROM 'plaid_internal_transfer'
     OR v_synth_amt IS DISTINCT FROM 160.00
     OR v_synth_from IS DISTINCT FROM v_acc_a
     OR v_synth_to IS DISTINCT FROM v_acc_b
     OR v_synth_cat IS NOT NULL
     OR v_synth_arch IS NOT NULL
  THEN
    RAISE EXCEPTION 'G7: synthetic fields mismatch type=% source=% amt=% from=% to=% cat=% arch=%',
      v_synth_type, v_synth_source, v_synth_amt, v_synth_from, v_synth_to, v_synth_cat, v_synth_arch;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.operations o
    WHERE o.id = v_transfer_id
      AND o.currency_code = 'USD'
      AND o.occurred_at = DATE '2026-08-06'
      AND o.is_recurring = false
      AND o.recurrence = 'none'
      AND o.category_overridden = false
      AND o.note IS NULL
  ) THEN
    RAISE EXCEPTION 'G7: synthetic secondary fields mismatch';
  END IF;

  -- =========================================================================
  -- G8: source-sync cannot resurrect confirmed legs
  -- =========================================================================
  SELECT o.amount INTO v_amt_out FROM public.operations o WHERE o.id = v_op_out;
  SELECT o.amount INTO v_amt_in FROM public.operations o WHERE o.id = v_op_in;
  UPDATE public.operations
  SET archived_at = NULL
  WHERE id IN (v_op_out, v_op_in) AND user_id = v_user_id;
  UPDATE public.plaid_transactions
  SET amount = 999.00
  WHERE id = (v_payload->>'raw_out')::uuid;
  UPDATE public.plaid_transactions
  SET amount = -999.00
  WHERE id = (v_payload->>'raw_in')::uuid;
  v_sync := pg_temp.run_source_sync(v_user_id, v_item_id, v_lease_token);
  IF coalesce(v_sync->>'status', '') IS DISTINCT FROM 'processed' THEN
    RAISE EXCEPTION 'G8: sync lease failed %', v_sync;
  END IF;
  SELECT o.archived_at, o.amount INTO v_archived_out, v_amt_out
  FROM public.operations o WHERE o.id = v_op_out;
  SELECT o.archived_at, o.amount INTO v_archived_in, v_amt_in
  FROM public.operations o WHERE o.id = v_op_in;
  IF v_archived_out IS NULL OR v_archived_in IS NULL THEN
    RAISE EXCEPTION 'G8: confirmed legs were resurrected (unarchived) sync=%', v_sync;
  END IF;
  IF v_amt_out IS DISTINCT FROM 160.00 OR v_amt_in IS DISTINCT FROM 160.00 THEN
    RAISE EXCEPTION 'G8: confirmed leg amounts mutated by source-sync out=% in=%', v_amt_out, v_amt_in;
  END IF;
  -- restore raw amounts for later consistency cases that reuse this pair? leave mismatched —
  -- this recon is now inconsistent; fine for subsequent independent fixtures.

  -- =========================================================================
  -- G9: one leg amount modified → inconsistent amount_mismatch
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g9', 190.00, DATE '2026-08-09');
  v_raw_out := (v_payload->>'raw_out')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G9: confirm failed %', v_result;
  END IF;
  UPDATE public.plaid_transactions SET amount = 191.00 WHERE id = v_raw_out;
  v_metrics := public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  SELECT r.inconsistency_code, r.inconsistent_at
    INTO v_code, v_inconsistent_at
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_code IS DISTINCT FROM 'amount_mismatch' OR v_inconsistent_at IS NULL THEN
    RAISE EXCEPTION 'G9: expected amount_mismatch, got code=% at=% metrics=%',
      v_code, v_inconsistent_at, v_metrics;
  END IF;

  -- =========================================================================
  -- G10: both legs converge to new equal amount → remains amount_mismatch
  -- =========================================================================
  UPDATE public.plaid_transactions SET amount = 200.00 WHERE id = v_raw_out;
  UPDATE public.plaid_transactions
  SET amount = -200.00
  WHERE id = (v_payload->>'raw_in')::uuid;
  v_metrics := public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  SELECT r.inconsistency_code INTO v_code
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_code IS DISTINCT FROM 'amount_mismatch' THEN
    RAISE EXCEPTION 'G10: expected still amount_mismatch, got % metrics=%', v_code, v_metrics;
  END IF;

  -- =========================================================================
  -- G11: restored exact snapshot → inconsistency clears
  -- =========================================================================
  UPDATE public.plaid_transactions SET amount = 190.00 WHERE id = v_raw_out;
  UPDATE public.plaid_transactions
  SET amount = -190.00
  WHERE id = (v_payload->>'raw_in')::uuid;
  v_metrics := public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  SELECT r.inconsistency_code, r.inconsistent_at
    INTO v_code, v_inconsistent_at
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_code IS NOT NULL OR v_inconsistent_at IS NOT NULL THEN
    RAISE EXCEPTION 'G11: expected cleared inconsistency, got code=% at=% metrics=%',
      v_code, v_inconsistent_at, v_metrics;
  END IF;

  -- =========================================================================
  -- G12: removed leg → leg_removed
  -- =========================================================================
  UPDATE public.plaid_transactions
  SET removed_at = now()
  WHERE id = (v_payload->>'raw_in')::uuid;
  v_metrics := public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  SELECT r.inconsistency_code INTO v_code
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_code IS DISTINCT FROM 'leg_removed' THEN
    RAISE EXCEPTION 'G12: expected leg_removed, got % metrics=%', v_code, v_metrics;
  END IF;

  -- =========================================================================
  -- G13: PFC break → pfc_policy_broken
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g13', 213.00, DATE '2026-08-13');
  v_raw_out := (v_payload->>'raw_out')::uuid;
  v_raw_in := (v_payload->>'raw_in')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G13: confirm failed %', v_result;
  END IF;
  UPDATE public.plaid_transactions
  SET
    personal_finance_category_primary = 'FOOD_AND_DRINK',
    personal_finance_category_detailed = 'FOOD_AND_DRINK_GROCERIES'
  WHERE id IN (v_raw_out, v_raw_in);
  v_metrics := public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  SELECT r.inconsistency_code INTO v_code
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_code IS DISTINCT FROM 'pfc_policy_broken' THEN
    RAISE EXCEPTION 'G13: expected pfc_policy_broken, got % metrics=%', v_code, v_metrics;
  END IF;

  -- =========================================================================
  -- G14: date break → date_policy_broken
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g14', 214.00, DATE '2026-08-14');
  v_raw_out := (v_payload->>'raw_out')::uuid;
  v_raw_in := (v_payload->>'raw_in')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G14: confirm failed %', v_result;
  END IF;
  UPDATE public.plaid_transactions
  SET date = DATE '2026-08-20', authorized_date = NULL
  WHERE id = v_raw_out;
  UPDATE public.plaid_transactions
  SET authorized_date = NULL
  WHERE id = v_raw_in;
  v_metrics := public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  SELECT r.inconsistency_code INTO v_code
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_code IS DISTINCT FROM 'date_policy_broken' THEN
    RAISE EXCEPTION 'G14: expected date_policy_broken, got % metrics=%', v_code, v_metrics;
  END IF;

  -- =========================================================================
  -- G15: Stage E suppressed blocks confirm
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g15', 215.00, DATE '2026-08-15');
  v_op_out := (v_payload->>'op_out')::uuid;
  v_op_in := (v_payload->>'op_in')::uuid;
  v_can_a := (v_payload->>'can_a')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_op_kept := pg_temp.next_id();
  INSERT INTO public.operations (
    id, user_id, from_account_id, to_account_id, type, amount,
    currency_code, occurred_at, source, category_id, archived_at,
    category_overridden, recurrence, is_recurring
  ) VALUES (
    v_op_kept, v_user_id, (v_payload->>'acc_a')::uuid, null, 'expense', 215.00,
    'USD', DATE '2026-08-15', 'plaid', null, null, false, 'none', false
  );
  INSERT INTO public.plaid_duplicate_operation_resolutions (
    user_id, canonical_account_id, kept_operation_id, suppressed_operation_id,
    resolved_at, reversed_at
  ) VALUES (
    v_user_id, v_can_a, v_op_kept, v_op_out, now(), null
  );
  SELECT count(*)::int INTO v_count
  FROM public.operations o
  WHERE o.user_id = v_user_id AND o.source = 'plaid_internal_transfer';
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'rejected' THEN
    RAISE EXCEPTION 'G15: expected rejected for Stage E suppressed leg, got %', v_result;
  END IF;
  IF (
    SELECT count(*)::int
    FROM public.operations o
    WHERE o.user_id = v_user_id AND o.source = 'plaid_internal_transfer'
  ) <> v_count THEN
    RAISE EXCEPTION 'G15: synthetic created despite Stage E suppression';
  END IF;

  -- =========================================================================
  -- G16: Stage E resolution on confirmed leg rejected
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g16', 216.00, DATE '2026-08-16');
  v_op_out := (v_payload->>'op_out')::uuid;
  v_op_in := (v_payload->>'op_in')::uuid;
  v_can_a := (v_payload->>'can_a')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G16: confirm failed %', v_result;
  END IF;
  v_op_kept := pg_temp.next_id();
  INSERT INTO public.operations (
    id, user_id, from_account_id, to_account_id, type, amount,
    currency_code, occurred_at, source, category_id, archived_at,
    category_overridden, recurrence, is_recurring
  ) VALUES (
    v_op_kept, v_user_id, (v_payload->>'acc_a')::uuid, null, 'expense', 216.00,
    'USD', DATE '2026-08-16', 'plaid', null, null, false, 'none', false
  );
  BEGIN
    PERFORM public.plaid_resolve_duplicate_operations(v_user_id, v_op_kept, v_op_out);
    RAISE EXCEPTION 'G16: expected confirmed_internal_transfer_leg exception';
  EXCEPTION
    WHEN others THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF position('confirmed_internal_transfer_leg' IN v_err) = 0 THEN
        RAISE EXCEPTION 'G16: unexpected error %', v_err;
      END IF;
  END;

  -- =========================================================================
  -- G17: canonical authority/membership change → C1 inconsistency
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g17', 217.00, DATE '2026-08-17');
  v_acc_a := (v_payload->>'acc_a')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G17: confirm failed %', v_result;
  END IF;
  UPDATE public.plaid_canonical_financial_account_members m
  SET unlinked_at = now()
  WHERE m.user_id = v_user_id
    AND m.account_id = v_acc_a
    AND m.unlinked_at IS NULL;
  -- C1 owner path: link RPC also reconciles; call consistency RPC directly after membership change
  v_metrics := public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  SELECT r.inconsistency_code INTO v_code
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_code IS DISTINCT FROM 'membership_missing' THEN
    RAISE EXCEPTION 'G17: expected membership_missing, got % metrics=%', v_code, v_metrics;
  END IF;

  -- =========================================================================
  -- G18: reverse archives synthetic; legs remain archived until sync
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g18', 218.00, DATE '2026-08-18');
  v_op_out := (v_payload->>'op_out')::uuid;
  v_op_in := (v_payload->>'op_in')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G18: confirm failed %', v_result;
  END IF;
  v_transfer_id := (v_result->>'transfer_operation_id')::uuid;
  v_result := public.plaid_reverse_internal_transfer_resolution(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'reversed' THEN
    RAISE EXCEPTION 'G18: reverse failed %', v_result;
  END IF;
  SELECT o.archived_at INTO v_synth_arch FROM public.operations o WHERE o.id = v_transfer_id;
  SELECT o.archived_at INTO v_archived_out FROM public.operations o WHERE o.id = v_op_out;
  SELECT o.archived_at INTO v_archived_in FROM public.operations o WHERE o.id = v_op_in;
  IF v_synth_arch IS NULL THEN
    RAISE EXCEPTION 'G18: synthetic must be archived on reverse';
  END IF;
  IF v_archived_out IS NULL OR v_archived_in IS NULL THEN
    RAISE EXCEPTION 'G18: legs must remain archived until source-sync';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state = 'reversed' AND r.reversed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'G18: reconciliation not marked reversed';
  END IF;

  -- =========================================================================
  -- G19: post-reverse source-sync rehydrates active legs
  -- =========================================================================
  v_sync := pg_temp.run_source_sync(v_user_id, v_item_id, v_lease_token);
  IF coalesce(v_sync->>'status', '') IS DISTINCT FROM 'processed' THEN
    RAISE EXCEPTION 'G19: sync lease failed %', v_sync;
  END IF;
  SELECT o.archived_at, o.amount INTO v_archived_out, v_amt_out
  FROM public.operations o WHERE o.id = v_op_out;
  SELECT o.archived_at, o.amount INTO v_archived_in, v_amt_in
  FROM public.operations o WHERE o.id = v_op_in;
  IF v_archived_out IS NOT NULL OR v_archived_in IS NOT NULL THEN
    RAISE EXCEPTION 'G19: legs not rehydrated/unarchived after reverse sync=%', v_sync;
  END IF;
  IF v_amt_out IS DISTINCT FROM 218.00 OR v_amt_in IS DISTINCT FROM 218.00 THEN
    RAISE EXCEPTION 'G19: rehydrated amounts wrong out=% in=%', v_amt_out, v_amt_in;
  END IF;
  -- freeze helper must be false after reverse
  IF public.plaid_operation_is_confirmed_internal_transfer_leg(v_user_id, v_op_out)
     OR public.plaid_operation_is_confirmed_internal_transfer_leg(v_user_id, v_op_in)
  THEN
    RAISE EXCEPTION 'G19: freeze helper still true after reverse';
  END IF;

  -- =========================================================================
  -- G20: repeated reverse idempotent
  -- =========================================================================
  v_result := public.plaid_reverse_internal_transfer_resolution(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'already_reversed' THEN
    RAISE EXCEPTION 'G20: expected already_reversed, got %', v_result;
  END IF;
  IF (v_result->>'transfer_operation_id')::uuid IS DISTINCT FROM v_transfer_id THEN
    RAISE EXCEPTION 'G20: transfer_operation_id changed on repeat reverse';
  END IF;

  -- =========================================================================
  -- G21: reversed terminal — detector no-op (no reactivate)
  -- =========================================================================
  -- legs are active again; same amounts/dates would form a bijective pair, but
  -- reversed row is terminal and legs are excluded from eligibility.
  v_metrics := public.plaid_reconcile_internal_transfer_candidates_for_user(v_user_id);
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id AND r.state <> 'reversed'
  ) THEN
    RAISE EXCEPTION 'G21: reversed row mutated by detector';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.user_id = v_user_id
      AND r.outgoing_projection_id = v_proj_out
      AND r.incoming_projection_id = v_proj_in
      AND r.state = 'candidate'
  ) THEN
    RAISE EXCEPTION 'G21: detector recreated candidate for reversed pair metrics=%', v_metrics;
  END IF;

  -- =========================================================================
  -- G22: confirm reversed rejected
  -- =========================================================================
  BEGIN
    PERFORM public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
    RAISE EXCEPTION 'G22: expected reversed exception';
  EXCEPTION
    WHEN others THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF position('reversed' IN v_err) = 0 THEN
        RAISE EXCEPTION 'G22: unexpected error %', v_err;
      END IF;
  END;

  -- =========================================================================
  -- G23: transfer_operation_id preserved forever
  -- =========================================================================
  SELECT r.transfer_operation_id, r.confirmed_at, r.reversed_at, r.confirmed_snapshot
    INTO v_transfer_id_2, v_confirmed_at, v_reversed_at, v_snap
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_transfer_id_2 IS DISTINCT FROM v_transfer_id
     OR v_confirmed_at IS NULL
     OR v_reversed_at IS NULL
     OR v_snap IS NULL
  THEN
    RAISE EXCEPTION 'G23: transfer_operation_id / confirmation metadata not preserved';
  END IF;

  -- =========================================================================
  -- G24: confirmed detector does not invalidate/refresh
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g24', 224.00, DATE '2026-08-24');
  v_raw_out := (v_payload->>'raw_out')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G24: confirm failed %', v_result;
  END IF;
  SELECT r.evidence_snapshot, r.confirmed_snapshot, r.confirmed_at
    INTO v_evidence, v_snap, v_confirmed_at
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  UPDATE public.plaid_transactions SET amount = 225.00 WHERE id = v_raw_out;
  v_metrics := public.plaid_reconcile_internal_transfer_candidates_for_user(v_user_id);
  SELECT r.state, r.evidence_snapshot, r.confirmed_snapshot, r.confirmed_at
    INTO v_state, v_payload, v_snap2, v_reversed_at
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_state IS DISTINCT FROM 'confirmed' THEN
    RAISE EXCEPTION 'G24: detector changed confirmed state to %', v_state;
  END IF;
  IF v_payload IS DISTINCT FROM v_evidence THEN
    RAISE EXCEPTION 'G24: detector refreshed evidence_snapshot on confirmed row';
  END IF;
  IF v_snap2 IS DISTINCT FROM v_snap OR v_reversed_at IS DISTINCT FROM v_confirmed_at THEN
    RAISE EXCEPTION 'G24: confirmed_snapshot/confirmed_at mutated by detector';
  END IF;

  -- =========================================================================
  -- G25: synthetic Operation unchanged by source-sync
  -- =========================================================================
  v_transfer_id := (
    SELECT r.transfer_operation_id
    FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id
  );
  SELECT to_jsonb(o) INTO v_snap
  FROM public.operations o
  WHERE o.id = v_transfer_id;
  UPDATE public.plaid_transactions t
  SET amount = CASE
    WHEN r.outgoing_projection_id = p.id THEN 300.00
    ELSE -300.00
  END
  FROM public.plaid_transaction_operation_projections p
  JOIN public.plaid_internal_transfer_reconciliations r
    ON r.id = v_recon_id
   AND (r.outgoing_projection_id = p.id OR r.incoming_projection_id = p.id)
  WHERE p.plaid_item_id = t.plaid_item_id
    AND p.plaid_transaction_id = t.transaction_id
    AND t.user_id = v_user_id;
  v_sync := pg_temp.run_source_sync(v_user_id, v_item_id, v_lease_token);
  IF coalesce(v_sync->>'status', '') IS DISTINCT FROM 'processed' THEN
    RAISE EXCEPTION 'G25: sync lease failed %', v_sync;
  END IF;
  SELECT to_jsonb(o) INTO v_snap2
  FROM public.operations o
  WHERE o.id = v_transfer_id;
  IF v_snap IS DISTINCT FROM v_snap2 THEN
    RAISE EXCEPTION 'G25: synthetic mutated by source-sync';
  END IF;
  IF (v_snap2->>'source') IS DISTINCT FROM 'plaid_internal_transfer' THEN
    RAISE EXCEPTION 'G25: synthetic source changed';
  END IF;

  -- =========================================================================
  -- G26: atomic failure leaves zero partial confirmation
  --
  -- Honest scope (no production RPC / schema mutation):
  -- Post-revalidation failure after INSERT synthetic cannot be legally induced
  -- from the harness without orphan DELETE (RESTRICT), artificial triggers, or
  -- constraint disable — all forbidden. Therefore G26 is:
  --   (1) STRUCTURAL: confirm is one plpgsql SECURITY DEFINER function TX;
  --       body contains INSERT operations + UPDATE operations + UPDATE
  --       reconciliations; no EXCEPTION handler that could swallow post-mutation
  --       failure. Exact statement order is NOT asserted via fragile
  --       pg_get_functiondef substring positions (PG reformats bodies).
  --   (2) RUNTIME: legal stale fixture (soft-remove via removed_at, NOT DELETE)
  --       forces reject BEFORE synthetic creation; assert zero partial
  --       confirmation residue (transfer/snapshot/confirmed_at/leg archive).
  -- Intentional invalidate on stale reject is allowed; confirmation fields are not.
  -- =========================================================================
  SELECT pg_get_functiondef(
    'public.plaid_confirm_internal_transfer_candidate(uuid,uuid)'::regprocedure
  )
  INTO v_def;
  IF v_def IS NULL OR strpos(v_def, 'plaid_confirm_internal_transfer_candidate') = 0 THEN
    RAISE EXCEPTION 'G26: confirm RPC definition missing';
  END IF;
  IF lower(v_def) ~ 'exception[[:space:]]+when' THEN
    RAISE EXCEPTION 'G26: confirm RPC has EXCEPTION handler (partial-commit risk)';
  END IF;
  IF lower(v_def) !~ 'language[[:space:]]+plpgsql' THEN
    RAISE EXCEPTION 'G26: confirm RPC is not plpgsql (single-function TX expected)';
  END IF;
  IF lower(v_def) !~ 'security[[:space:]]+definer' THEN
    RAISE EXCEPTION 'G26: confirm RPC is not SECURITY DEFINER';
  END IF;
  -- Presence of confirmation mutation statements (not fragile position-order).
  IF lower(v_def) !~ 'insert[[:space:]]+into[[:space:]]+public\.operations' THEN
    RAISE EXCEPTION 'G26: confirm RPC missing INSERT INTO public.operations';
  END IF;
  IF lower(v_def) !~ 'update[[:space:]]+public\.operations' THEN
    RAISE EXCEPTION 'G26: confirm RPC missing UPDATE public.operations';
  END IF;
  IF lower(v_def) !~ 'update[[:space:]]+public\.plaid_internal_transfer_reconciliations' THEN
    RAISE EXCEPTION 'G26: confirm RPC missing UPDATE public.plaid_internal_transfer_reconciliations';
  END IF;

  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g26', 226.00, DATE '2026-08-26');
  v_raw_out := (v_payload->>'raw_out')::uuid;
  v_op_out := (v_payload->>'op_out')::uuid;
  v_op_in := (v_payload->>'op_in')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  SELECT count(*)::int INTO v_count
  FROM public.operations o
  WHERE o.user_id = v_user_id AND o.source = 'plaid_internal_transfer';

  -- Legal stale: soft-remove raw (schema-valid). Projection FK remains intact.
  -- Do NOT DELETE plaid_transactions rows referenced by projections (RESTRICT).
  UPDATE public.plaid_transactions
  SET removed_at = now()
  WHERE id = v_raw_out
    AND user_id = v_user_id
    AND removed_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'G26: failed to soft-remove outgoing raw for stale fixture';
  END IF;

  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'rejected' THEN
    RAISE EXCEPTION 'G26: expected rejected, got %', v_result;
  END IF;
  IF coalesce(v_result->>'reason', '') <> 'stale_candidate' THEN
    RAISE EXCEPTION 'G26: expected stale_candidate reason, got %', v_result;
  END IF;
  IF (
    SELECT count(*)::int
    FROM public.operations o
    WHERE o.user_id = v_user_id AND o.source = 'plaid_internal_transfer'
  ) <> v_count THEN
    RAISE EXCEPTION 'G26: partial synthetic left after rejected confirm';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id
      AND (
        r.state = 'confirmed'
        OR r.transfer_operation_id IS NOT NULL
        OR r.confirmed_snapshot IS NOT NULL
        OR r.confirmed_at IS NOT NULL
        OR r.reversed_at IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'G26: partial confirmation fields set on reject';
  END IF;
  -- Stale reject may intentionally invalidate; never confirm.
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_internal_transfer_reconciliations r
    WHERE r.id = v_recon_id
      AND r.state = 'invalidated'
      AND r.invalidated_at IS NOT NULL
      AND r.transfer_operation_id IS NULL
      AND r.confirmed_at IS NULL
      AND r.confirmed_snapshot IS NULL
  ) THEN
    RAISE EXCEPTION 'G26: expected invalidated candidate without confirmation residue';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.operations o
    WHERE o.id IN (v_op_out, v_op_in) AND o.archived_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'G26: legs archived on rejected confirm';
  END IF;
  -- Projection↔raw FK still intact after soft-remove (no orphan DELETE).
  IF NOT EXISTS (
    SELECT 1
    FROM public.plaid_transaction_operation_projections p
    JOIN public.plaid_transactions t
      ON t.plaid_item_id = p.plaid_item_id
     AND t.transaction_id = p.plaid_transaction_id
     AND t.user_id = p.user_id
    WHERE p.id = v_proj_out
      AND t.id = v_raw_out
      AND t.removed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'G26: outgoing projection/raw link broken after soft-remove';
  END IF;

  -- =========================================================================
  -- G27: source = 'plaid_internal_transfer'
  -- =========================================================================
  IF NOT EXISTS (
    SELECT 1
    FROM public.operations o
    WHERE o.user_id = v_user_id
      AND o.source = 'plaid_internal_transfer'
      AND o.type = 'transfer'
  ) THEN
    RAISE EXCEPTION 'G27: no plaid_internal_transfer synthetic exists';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid = 'public.operations'::regclass
      AND c.conname = 'operations_source_check'
      AND position('plaid_internal_transfer' IN pg_get_constraintdef(c.oid)) > 0
  ) THEN
    RAISE EXCEPTION 'G27: operations_source_check missing plaid_internal_transfer';
  END IF;

  -- =========================================================================
  -- G28: confirmed_snapshot immutable
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g28', 228.00, DATE '2026-08-28');
  v_raw_out := (v_payload->>'raw_out')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G28: confirm failed %', v_result;
  END IF;
  SELECT r.confirmed_snapshot INTO v_snap
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  UPDATE public.plaid_transactions SET amount = 229.00 WHERE id = v_raw_out;
  PERFORM public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  PERFORM public.plaid_reconcile_internal_transfer_candidates_for_user(v_user_id);
  SELECT r.confirmed_snapshot, r.inconsistency_code
    INTO v_snap2, v_code
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_snap2 IS DISTINCT FROM v_snap THEN
    RAISE EXCEPTION 'G28: confirmed_snapshot mutated';
  END IF;
  IF v_code IS DISTINCT FROM 'amount_mismatch' THEN
    RAISE EXCEPTION 'G28: expected amount_mismatch after mutation, got %', v_code;
  END IF;
  IF (v_snap->>'amount')::numeric IS DISTINCT FROM 228.00 THEN
    RAISE EXCEPTION 'G28: snapshot amount drifted from confirmation truth';
  END IF;

  -- =========================================================================
  -- G29: one removed then restored exact snapshot → consistency clears
  -- =========================================================================
  v_payload := pg_temp.setup_chk_sav_pair(
    v_user_id, v_item_id, 'g29', 229.00, DATE '2026-08-29');
  v_raw_in := (v_payload->>'raw_in')::uuid;
  v_proj_out := (v_payload->>'proj_out')::uuid;
  v_proj_in := (v_payload->>'proj_in')::uuid;
  v_recon_id := pg_temp.detect_and_get_recon(v_user_id, v_proj_out, v_proj_in);
  v_result := public.plaid_confirm_internal_transfer_candidate(v_user_id, v_recon_id);
  IF coalesce(v_result->>'status', '') <> 'confirmed' THEN
    RAISE EXCEPTION 'G29: confirm failed %', v_result;
  END IF;
  UPDATE public.plaid_transactions SET removed_at = now() WHERE id = v_raw_in;
  PERFORM public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  SELECT r.inconsistency_code INTO v_code
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_code IS DISTINCT FROM 'leg_removed' THEN
    RAISE EXCEPTION 'G29: expected leg_removed, got %', v_code;
  END IF;
  UPDATE public.plaid_transactions SET removed_at = NULL WHERE id = v_raw_in;
  v_metrics := public.plaid_reconcile_confirmed_internal_transfers_for_user(v_user_id);
  SELECT r.inconsistency_code, r.inconsistent_at
    INTO v_code, v_inconsistent_at
  FROM public.plaid_internal_transfer_reconciliations r
  WHERE r.id = v_recon_id;
  IF v_code IS NOT NULL OR v_inconsistent_at IS NOT NULL THEN
    RAISE EXCEPTION 'G29: expected cleared after restore, got code=% at=% metrics=%',
      v_code, v_inconsistent_at, v_metrics;
  END IF;

  -- =========================================================================
  -- Structural: advisory namespace 872514002 + unique indexes
  -- =========================================================================
  SELECT pg_get_functiondef(
    'public.plaid_confirm_internal_transfer_candidate(uuid,uuid)'::regprocedure
  ) INTO v_def;
  IF position('872514002' IN v_def) = 0 OR position('pg_advisory_xact_lock' IN v_def) = 0 THEN
    RAISE EXCEPTION 'STRUCT: confirm missing advisory namespace 872514002';
  END IF;
  SELECT pg_get_functiondef(
    'public.plaid_reverse_internal_transfer_resolution(uuid,uuid)'::regprocedure
  ) INTO v_def;
  IF position('872514002' IN v_def) = 0 THEN
    RAISE EXCEPTION 'STRUCT: reverse missing advisory namespace 872514002';
  END IF;
  SELECT pg_get_functiondef(
    'public.plaid_reconcile_confirmed_internal_transfers_for_user(uuid)'::regprocedure
  ) INTO v_def;
  IF position('872514002' IN v_def) = 0 THEN
    RAISE EXCEPTION 'STRUCT: reconcile_confirmed missing advisory namespace 872514002';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_itr_transfer_operation_uidx'
  ) THEN
    RAISE EXCEPTION 'STRUCT: missing unique transfer_operation_id index';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_itr_confirmed_outgoing_projection_uidx'
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_itr_confirmed_incoming_projection_uidx'
  ) THEN
    RAISE EXCEPTION 'STRUCT: missing confirmed projection unique indexes';
  END IF;
  SELECT pg_get_functiondef(
    'public.plaid_sync_materialized_transaction_operations(uuid,uuid,uuid,integer)'::regprocedure
  ) INTO v_def;
  IF position('plaid_operation_is_confirmed_internal_transfer_leg' IN v_def) = 0 THEN
    RAISE EXCEPTION 'STRUCT: source-sync missing confirmed-leg freeze helper';
  END IF;

  -- =========================================================================
  -- G30: zero Manual mutations from Stage G SQL paths
  -- =========================================================================
  SELECT to_jsonb(o) INTO v_manual_after
  FROM public.operations o
  WHERE o.id = v_manual_op_id;
  IF v_manual_before IS DISTINCT FROM v_manual_after THEN
    RAISE EXCEPTION 'G30: manual operation mutated by Stage G harness RPCs';
  END IF;
  PERFORM pg_temp.assert_ops_unchanged('G30', v_user_id);
  -- also ensure reconciles/confirms did not create a second copy / archive manual
  IF NOT EXISTS (
    SELECT 1 FROM public.operations o
    WHERE o.id = v_manual_op_id
      AND o.source = 'manual'
      AND o.archived_at IS NULL
      AND o.note = 'stage-g-manual-sentinel'
      AND o.amount = 12.34
  ) THEN
    RAISE EXCEPTION 'G30: manual sentinel row altered';
  END IF;

  RAISE NOTICE 'STAGE_G_VALIDATION_PASS';
END;
$$;

SELECT 'STAGE_G_VALIDATION_PASS' AS stage_g_validation_result;

ROLLBACK;
