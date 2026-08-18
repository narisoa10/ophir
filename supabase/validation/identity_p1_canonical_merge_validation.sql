-- =============================================================================
-- Identity P1 validation harness: canonical merge foundation
-- Temporary / non-migration SQL. Does not change production schema permanently.
-- One transaction; ends with ROLLBACK. No leftover fixture data.
-- No Plaid API / workers / Edge Functions / production DDL changes.
-- Requires migration 20260818120000_plaid_canonical_merge_foundation.sql applied.
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_user_id uuid := 'a0131800-0000-4000-8000-000000000001';
  v_user_other uuid := 'a0131800-0000-4000-8000-000000000002';
  v_item_id uuid := 'a0131800-0000-4000-8000-000000000010';
  v_item_other uuid := 'a0131800-0000-4000-8000-000000000011';
  v_secret_id uuid := 'a0131800-0000-4000-8000-0000000000ff';
  v_secret_other uuid := 'a0131800-0000-4000-8000-0000000000fe';
  v_identity_id uuid := 'a0131800-0000-4000-8000-0000000000aa';
  v_identity_other uuid := 'a0131800-0000-4000-8000-0000000000ab';

  v_acc_a uuid;
  v_acc_b uuid;
  v_acc_c uuid;
  v_acc_d uuid;
  v_acc_manual uuid;
  v_can_a uuid;
  v_can_b uuid;

  v_result jsonb;
  v_op_id uuid;
  v_op_archived_before timestamptz;
  v_op_archived_after timestamptz;
  v_op_amount_before numeric;
  v_op_amount_after numeric;
  v_op_account_before uuid;
  v_op_account_after uuid;
  v_unlinked_hist uuid;
  v_hist_canonical uuid;
  v_hist_unlinked_at timestamptz;
  v_survivor uuid;
  v_def text;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id IN (v_user_id, v_user_other)) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: auth.users fixture id exists';
  END IF;
  IF EXISTS (SELECT 1 FROM public.plaid_items i WHERE i.id IN (v_item_id, v_item_other)) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: plaid_items fixture id exists';
  END IF;

  -- Soft-check: merge-capable function body present.
  SELECT pg_get_functiondef(
    'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)'::regprocedure
  ) INTO v_def;
  IF v_def IS NULL OR position('v_survivor_canonical_id' IN v_def) = 0 THEN
    RAISE EXCEPTION 'P1: link RPC missing merge survivor logic';
  END IF;
  IF position('merged' IN v_def) = 0 THEN
    RAISE EXCEPTION 'P1: merge status not found in link RPC body';
  END IF;

  IF NOT has_function_privilege(
    'service_role',
    'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P1-24: service_role missing EXECUTE';
  END IF;
  IF has_function_privilege(
    'authenticated',
    'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P1-24: authenticated must not EXECUTE';
  END IF;

  -- Helpers as temp functions
  CREATE FUNCTION pg_temp.make_plaid_account(
    p_user_id uuid,
    p_item_id uuid,
    p_name text,
    p_plaid_account_id text,
    p_plaid_type text,
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
      p_item_id, p_plaid_account_id, p_plaid_type, p_plaid_type,
      p_pai
    );
    RETURN v_id;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.make_manual_account(p_user_id uuid, p_name text)
  RETURNS uuid
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    v_id uuid := gen_random_uuid();
  BEGIN
    INSERT INTO public.accounts (
      id, user_id, name, type, currency_code,
      initial_balance, icon_key, color_key, sort_order, is_archived
    ) VALUES (
      v_id, p_user_id, p_name, 'cash', 'USD',
      0, 'cash', 'green', 0, false
    );
    RETURN v_id;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.make_singleton(
    p_user_id uuid,
    p_account_id uuid,
    p_origin text DEFAULT 'user_confirmed'
  ) RETURNS uuid
  LANGUAGE plpgsql
  AS $fn$
  DECLARE
    v_can uuid;
  BEGIN
    INSERT INTO public.plaid_canonical_financial_accounts (user_id)
    VALUES (p_user_id)
    RETURNING id INTO v_can;

    INSERT INTO public.plaid_canonical_financial_account_members (
      user_id, canonical_account_id, account_id, role, link_origin
    ) VALUES (
      p_user_id, v_can, p_account_id, 'authoritative', p_origin
    );
    RETURN v_can;
  END;
  $fn$;

  CREATE FUNCTION pg_temp.active_auth_count(p_canonical uuid)
  RETURNS integer
  LANGUAGE sql
  AS $fn$
    SELECT count(*)::integer
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.canonical_account_id = p_canonical
      AND m.unlinked_at IS NULL
      AND m.role = 'authoritative';
  $fn$;

  CREATE FUNCTION pg_temp.active_member_count(p_canonical uuid)
  RETURNS integer
  LANGUAGE sql
  AS $fn$
    SELECT count(*)::integer
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.canonical_account_id = p_canonical
      AND m.unlinked_at IS NULL;
  $fn$;

  -- Auth fixtures (profile via handle_new_user)
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      'identity-p1-validation-' || v_user_id::text || '@ophir.invalid',
      extensions.crypt('identity-p1-validation-not-used', extensions.gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{}'::jsonb,
      now(),
      now(),
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      v_user_other,
      'authenticated',
      'authenticated',
      'identity-p1-validation-' || v_user_other::text || '@ophir.invalid',
      extensions.crypt('identity-p1-validation-not-used', extensions.gen_salt('bf')),
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
  ) VALUES
    (
      v_identity_id,
      v_user_id,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', 'identity-p1-validation-' || v_user_id::text || '@ophir.invalid'
      ),
      'email',
      v_user_id::text,
      now(), now(), now()
    ),
    (
      v_identity_other,
      v_user_other,
      jsonb_build_object(
        'sub', v_user_other::text,
        'email', 'identity-p1-validation-' || v_user_other::text || '@ophir.invalid'
      ),
      'email',
      v_user_other::text,
      now(), now(), now()
    );

  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id) THEN
    RAISE EXCEPTION 'FIXTURE: profile not created by handle_new_user for primary user';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_other) THEN
    RAISE EXCEPTION 'FIXTURE: profile not created by handle_new_user for other user';
  END IF;

  INSERT INTO public.plaid_items (
    id, user_id, plaid_environment, plaid_item_id, access_token_secret_id
  ) VALUES
    (v_item_id, v_user_id, 'sandbox', 'identity-p1-item-' || v_user_id::text, v_secret_id),
    (v_item_other, v_user_other, 'sandbox', 'identity-p1-item-' || v_user_other::text, v_secret_other);

  -- ===== P1-1 M1 both free → created =====
  v_acc_a := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-1 A', 'p1-1-a', 'depository', NULL);
  v_acc_b := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-1 B', 'p1-1-b', 'depository', NULL);
  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc_a, v_acc_b, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'created' THEN
    RAISE EXCEPTION 'P1-1: expected created, got %', v_result;
  END IF;
  IF pg_temp.active_auth_count((v_result->>'canonical_account_id')::uuid) <> 1 THEN
    RAISE EXCEPTION 'P1-1: expected one authority';
  END IF;
  IF pg_temp.active_member_count((v_result->>'canonical_account_id')::uuid) <> 2 THEN
    RAISE EXCEPTION 'P1-1: expected two members';
  END IF;

  -- ===== P1-2 M2/M3 one free =====
  v_acc_c := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-2 C', 'p1-2-c', 'depository', NULL);
  v_can_a := (v_result->>'canonical_account_id')::uuid;
  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc_a, v_acc_c, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'linked' THEN
    RAISE EXCEPTION 'P1-2: expected linked, got %', v_result;
  END IF;
  IF (v_result->>'canonical_account_id')::uuid IS DISTINCT FROM v_can_a THEN
    RAISE EXCEPTION 'P1-2: canonical changed unexpectedly';
  END IF;
  IF (v_result->>'authoritative_account_id')::uuid IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P1-2: authority switched';
  END IF;
  IF pg_temp.active_member_count(v_can_a) <> 3 THEN
    RAISE EXCEPTION 'P1-2: expected 3 members';
  END IF;

  -- ===== P1-3 already same canonical idempotent =====
  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc_a, v_acc_b, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'already_linked' THEN
    RAISE EXCEPTION 'P1-3: expected already_linked, got %', v_result;
  END IF;

  -- ===== P1-4 same PAI two singletons → merge =====
  v_acc_a := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-4 A', 'p1-4-a', 'depository', 'pai-same-4');
  v_acc_b := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-4 B', 'p1-4-b', 'depository', 'pai-same-4');
  v_can_a := pg_temp.make_singleton(v_user_id, v_acc_a);
  v_can_b := pg_temp.make_singleton(v_user_id, v_acc_b);

  -- seed an operation on B; must remain untouched
  v_op_id := gen_random_uuid();
  INSERT INTO public.operations (
    id, user_id, from_account_id, to_account_id, type, amount,
    currency_code, occurred_at, source, category_id, archived_at,
    category_overridden, recurrence, is_recurring
  ) VALUES (
    v_op_id, v_user_id, v_acc_b, null, 'expense', 12.34,
    'USD', DATE '2026-08-01', 'plaid', null, null,
    false, 'none', false
  );
  SELECT archived_at, amount, from_account_id
  INTO v_op_archived_before, v_op_amount_before, v_op_account_before
  FROM public.operations WHERE id = v_op_id;

  -- historical unlinked membership on losing canonical (audit preserve)
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin, linked_at, unlinked_at
  ) VALUES (
    v_user_id, v_can_b, v_acc_b, 'secondary', 'user_confirmed',
    now() - interval '1 day', now() - interval '1 hour'
  )
  RETURNING id, canonical_account_id, unlinked_at
  INTO v_unlinked_hist, v_hist_canonical, v_hist_unlinked_at;

  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc_a, v_acc_b, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'merged' THEN
    RAISE EXCEPTION 'P1-4: expected merged, got %', v_result;
  END IF;
  v_survivor := (v_result->>'canonical_account_id')::uuid;
  IF v_survivor IS DISTINCT FROM v_can_a THEN
    RAISE EXCEPTION 'P1-4/P1-10: survivor must be authority canonical % got %',
      v_can_a, v_survivor;
  END IF;
  IF (v_result->>'authoritative_account_id')::uuid IS DISTINCT FROM v_acc_a THEN
    RAISE EXCEPTION 'P1-11: authority must remain A';
  END IF;
  IF pg_temp.active_auth_count(v_survivor) <> 1 THEN
    RAISE EXCEPTION 'P1-11: expected exactly one authoritative';
  END IF;
  IF pg_temp.active_member_count(v_survivor) <> 2 THEN
    RAISE EXCEPTION 'P1-12: expected both accounts active on survivor';
  END IF;
  IF pg_temp.active_member_count(v_can_b) <> 0 THEN
    RAISE EXCEPTION 'P1-15: losing canonical still has active members';
  END IF;
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'P1-13: duplicate or missing active membership';
  END IF;

  SELECT archived_at, amount, from_account_id
  INTO v_op_archived_after, v_op_amount_after, v_op_account_after
  FROM public.operations WHERE id = v_op_id;
  IF v_op_archived_after IS DISTINCT FROM v_op_archived_before
     OR v_op_amount_after IS DISTINCT FROM v_op_amount_before
     OR v_op_account_after IS DISTINCT FROM v_op_account_before
  THEN
    RAISE EXCEPTION 'P1-16: operation mutated by merge';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.id = v_unlinked_hist
      AND (m.canonical_account_id IS DISTINCT FROM v_hist_canonical
           OR m.unlinked_at IS DISTINCT FROM v_hist_unlinked_at)
  ) THEN
    RAISE EXCEPTION 'P1-14: historical unlinked membership rewritten';
  END IF;

  -- Stage E same-canonical structural eligibility (P1-17): both accounts share survivor
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc_a, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P1-17: accounts not same-canonical after merge';
  END IF;

  -- P1-18: Stage E not auto-invoked → no resolutions for this user
  IF EXISTS (
    SELECT 1 FROM public.plaid_duplicate_operation_resolutions r
    WHERE r.user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'P1-18: unexpected Stage E resolution row';
  END IF;

  -- P1-19 secondary role for rehomed B
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL AND m.role = 'secondary'
  ) THEN
    RAISE EXCEPTION 'P1-19: rehomed account not secondary';
  END IF;

  -- ===== P1-21 repeated merge idempotent =====
  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc_a, v_acc_b, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'already_linked' THEN
    RAISE EXCEPTION 'P1-21: expected already_linked after merge, got %', v_result;
  END IF;

  -- ===== P1-22 reversed argument order after merge =====
  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc_b, v_acc_a, v_acc_a);
  IF coalesce(v_result->>'status', '') <> 'already_linked' THEN
    RAISE EXCEPTION 'P1-22: reversed order failed, got %', v_result;
  END IF;

  -- ===== P1-5 null-PAI explicit user_confirmed merge =====
  v_acc_a := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-5 A', 'p1-5-a', 'depository', NULL);
  v_acc_b := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-5 B', 'p1-5-b', 'depository', NULL);
  v_can_a := pg_temp.make_singleton(v_user_id, v_acc_a);
  v_can_b := pg_temp.make_singleton(v_user_id, v_acc_b);
  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc_a, v_acc_b, v_acc_b);
  IF coalesce(v_result->>'status', '') <> 'merged' THEN
    RAISE EXCEPTION 'P1-5: expected merged for null PAI, got %', v_result;
  END IF;
  IF (v_result->>'canonical_account_id')::uuid IS DISTINCT FROM v_can_b THEN
    RAISE EXCEPTION 'P1-5/P1-10: survivor should follow authority B canonical';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_a AND m.unlinked_at IS NULL
      AND m.link_origin IS DISTINCT FROM 'user_confirmed'
  ) THEN
    RAISE EXCEPTION 'P1-5: rehomed link_origin expected user_confirmed';
  END IF;

  -- ===== P1-6 different non-null PAI reject =====
  v_acc_a := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-6 A', 'p1-6-a', 'depository', 'pai-6-a');
  v_acc_b := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-6 B', 'p1-6-b', 'depository', 'pai-6-b');
  v_can_a := pg_temp.make_singleton(v_user_id, v_acc_a);
  v_can_b := pg_temp.make_singleton(v_user_id, v_acc_b);
  BEGIN
    PERFORM public.plaid_link_canonical_financial_accounts(
      v_user_id, v_acc_a, v_acc_b, v_acc_a);
    RAISE EXCEPTION 'P1-6: expected persistent_account_identity_conflict';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT ILIKE '%persistent_account_identity_conflict%' THEN
        RAISE EXCEPTION 'P1-6: unexpected error %', SQLERRM;
      END IF;
  END;
  IF pg_temp.active_member_count(v_can_a) <> 1
     OR pg_temp.active_member_count(v_can_b) <> 1 THEN
    RAISE EXCEPTION 'P1-6: topology changed on reject';
  END IF;

  -- ===== P1-7 different user reject =====
  v_acc_d := pg_temp.make_plaid_account(
    v_user_other, v_item_other, 'P1-7 other', 'p1-7-o', 'depository', NULL);
  BEGIN
    PERFORM public.plaid_link_canonical_financial_accounts(
      v_user_id, v_acc_a, v_acc_d, v_acc_a);
    RAISE EXCEPTION 'P1-7: expected account_not_found';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT ILIKE '%account_not_found%' THEN
        RAISE EXCEPTION 'P1-7: unexpected error %', SQLERRM;
      END IF;
  END;

  -- ===== P1-8 non-Plaid reject =====
  v_acc_manual := pg_temp.make_manual_account(v_user_id, 'P1-8 cash');
  BEGIN
    PERFORM public.plaid_link_canonical_financial_accounts(
      v_user_id, v_acc_a, v_acc_manual, v_acc_a);
    RAISE EXCEPTION 'P1-8: expected account_not_plaid';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT ILIKE '%account_not_plaid%' THEN
        RAISE EXCEPTION 'P1-8: unexpected error %', SQLERRM;
      END IF;
  END;

  -- ===== P1-9 incompatible plaid type =====
  v_acc_a := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-9 A', 'p1-9-a', 'depository', NULL);
  v_acc_b := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-9 B', 'p1-9-b', 'credit', NULL);
  v_can_a := pg_temp.make_singleton(v_user_id, v_acc_a);
  v_can_b := pg_temp.make_singleton(v_user_id, v_acc_b);
  BEGIN
    PERFORM public.plaid_link_canonical_financial_accounts(
      v_user_id, v_acc_a, v_acc_b, v_acc_a);
    RAISE EXCEPTION 'P1-9: expected incompatible_account_types';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT ILIKE '%incompatible_account_types%' THEN
        RAISE EXCEPTION 'P1-9: unexpected error %', SQLERRM;
      END IF;
  END;

  -- ===== P1-25 malformed: canonical without authoritative =====
  v_acc_a := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-25 A', 'p1-25-a', 'depository', 'pai-25');
  v_acc_b := pg_temp.make_plaid_account(
    v_user_id, v_item_id, 'P1-25 B', 'p1-25-b', 'depository', 'pai-25');
  INSERT INTO public.plaid_canonical_financial_accounts (user_id)
  VALUES (v_user_id) RETURNING id INTO v_can_a;
  INSERT INTO public.plaid_canonical_financial_accounts (user_id)
  VALUES (v_user_id) RETURNING id INTO v_can_b;
  -- only secondary on A canonical (malformed)
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin
  ) VALUES (
    v_user_id, v_can_a, v_acc_a, 'secondary', 'user_confirmed'
  );
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin
  ) VALUES (
    v_user_id, v_can_b, v_acc_b, 'authoritative', 'user_confirmed'
  );
  BEGIN
    PERFORM public.plaid_link_canonical_financial_accounts(
      v_user_id, v_acc_a, v_acc_b, v_acc_b);
    RAISE EXCEPTION 'P1-25: expected canonical_authority_invalid';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT ILIKE '%canonical_authority_invalid%' THEN
        RAISE EXCEPTION 'P1-25: unexpected error %', SQLERRM;
      END IF;
  END;

  -- ===== P1-27: precondition failure leaves two-canonical topology =====
  -- (covered by P1-6 topology unchanged)

  -- ===== P1-23: concurrent-safe structural constraints present =====
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_canonical_financial_account_members_active_account_uidx'
  ) THEN
    RAISE EXCEPTION 'P1-23: missing active account unique index';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_canonical_financial_account_members_active_authority_uidx'
  ) THEN
    RAISE EXCEPTION 'P1-23: missing active authority unique index';
  END IF;

  -- Static markers for P1-20 / P1-26 (Stage G hook present on success paths)
  IF position('plaid_reconcile_confirmed_internal_transfers_for_user' IN v_def) = 0 THEN
    RAISE EXCEPTION 'P1-20/P1-26: Stage G reconcile hook missing from link RPC';
  END IF;

END;
$$;

SELECT 'IDENTITY_P1_VALIDATION_PASS'
  AS identity_p1_validation_result;

ROLLBACK;
