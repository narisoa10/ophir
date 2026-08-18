-- =============================================================================
-- Identity P2 validation: singleton Plaid account identity bootstrap
-- BEGIN … ROLLBACK. Requires 20260818140000_plaid_singleton_identity_bootstrap.sql
-- PASS via SELECT (not NOTICE).
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_user_id uuid := 'a0b20000-0000-4000-8000-000000000001';
  v_user_other uuid := 'a0b20000-0000-4000-8000-000000000002';
  v_item_id uuid := 'a0b20000-0000-4000-8000-000000000010';
  v_item_other uuid := 'a0b20000-0000-4000-8000-000000000011';
  v_secret_id uuid := 'a0b20000-0000-4000-8000-0000000000ff';
  v_secret_other uuid := 'a0b20000-0000-4000-8000-0000000000fe';
  v_identity_id uuid := 'a0b20000-0000-4000-8000-0000000000aa';
  v_identity_other uuid := 'a0b20000-0000-4000-8000-0000000000ab';

  v_acc uuid;
  v_acc_b uuid;
  v_acc_manual uuid;
  v_can uuid;
  v_can_b uuid;
  v_result jsonb;
  v_result2 jsonb;
  v_synced integer;
  v_canons_before integer;
  v_canons_after integer;
  v_def_ensure text;
  v_def_persist text;
  v_def_p1 text;
  v_def_f text;
  v_missing uuid := 'a0b20000-0000-4000-8000-000000009999';
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id IN (v_user_id, v_user_other)) THEN
    RAISE EXCEPTION 'FIXTURE_COLLISION: auth.users';
  END IF;

  -- Structural: helpers/indexes/grants
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_canonical_financial_account_members_active_account_uidx'
  ) THEN
    RAISE EXCEPTION 'P2-20: active-account unique missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'plaid_canonical_financial_account_members_active_authority_uidx'
  ) THEN
    RAISE EXCEPTION 'P2-21: active-authority unique missing';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_ensure_account_identity(uuid,uuid)'::regprocedure
  ) INTO v_def_ensure;
  SELECT pg_get_functiondef(
    'public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)'::regprocedure
  ) INTO v_def_persist;

  IF position('for update' IN lower(v_def_ensure)) = 0 THEN
    RAISE EXCEPTION 'P2-22: ensure missing FOR UPDATE';
  END IF;
  IF position('plaid_ensure_account_identity' IN v_def_persist) = 0 THEN
    RAISE EXCEPTION 'P2-26: persist does not invoke ensure';
  END IF;
  IF position('plaid_link_canonical_financial_accounts' IN v_def_ensure) > 0
     OR position('plaid_link_canonical_financial_accounts' IN v_def_persist) > 0 THEN
    RAISE EXCEPTION 'P2-32: P2 must not call link/merge RPC';
  END IF;
  -- No sibling PAI scan in ensure body.
  IF position('persistent_account_id' IN v_def_ensure) > 0 THEN
    RAISE EXCEPTION 'P2-32: ensure must not query PAI siblings';
  END IF;

  IF NOT has_function_privilege(
    'service_role', 'public.plaid_ensure_account_identity(uuid,uuid)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P2-47: service_role missing EXECUTE on ensure';
  END IF;
  IF has_function_privilege(
    'authenticated', 'public.plaid_ensure_account_identity(uuid,uuid)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'P2-47: authenticated must not EXECUTE ensure';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)'::regprocedure
  ) INTO v_def_p1;
  IF position('v_survivor_canonical_id' IN v_def_p1) = 0 THEN
    RAISE EXCEPTION 'P2-42: P1 merge missing';
  END IF;

  SELECT pg_get_functiondef(
    'public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)'::regprocedure
  ) INTO v_def_f;
  IF position('stage_f_v2' IN v_def_f) = 0 THEN
    RAISE EXCEPTION 'P2-40: Stage F hardening body not present';
  END IF;

  -- link_origin allows sync_bootstrap
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname = 'plaid_canonical_financial_account_members'
      AND c.conname = 'plaid_canonical_financial_account_members_link_origin_check'
      AND pg_get_constraintdef(c.oid) ILIKE '%sync_bootstrap%'
  ) THEN
    RAISE EXCEPTION 'P2-6: sync_bootstrap not in link_origin check';
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
      'identity-p2-' || v_user_id::text || '@ophir.invalid',
      extensions.crypt('identity-p2-not-used', extensions.gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      now(), now(), '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000', v_user_other,
      'authenticated', 'authenticated',
      'identity-p2-' || v_user_other::text || '@ophir.invalid',
      extensions.crypt('identity-p2-not-used', extensions.gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      now(), now(), '', '', '', ''
    );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) VALUES
    (
      v_identity_id, v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', 'identity-p2-' || v_user_id::text || '@ophir.invalid'),
      'email', v_user_id::text, now(), now(), now()
    ),
    (
      v_identity_other, v_user_other,
      jsonb_build_object('sub', v_user_other::text, 'email', 'identity-p2-' || v_user_other::text || '@ophir.invalid'),
      'email', v_user_other::text, now(), now(), now()
    );

  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id)
     OR NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_other) THEN
    RAISE EXCEPTION 'FIXTURE: profile missing';
  END IF;

  INSERT INTO public.plaid_items (
    id, user_id, plaid_environment, plaid_item_id, access_token_secret_id
  ) VALUES
    (v_item_id, v_user_id, 'sandbox', 'identity-p2-item-' || v_user_id::text, v_secret_id),
    (v_item_other, v_user_other, 'sandbox', 'identity-p2-item-' || v_user_other::text, v_secret_other);

  -- ===== P2-1..P2-6 core ensure =====
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived,
    plaid_item_id, plaid_account_id, plaid_type, plaid_subtype,
    persistent_account_id
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P2 Core', 'bank', 'USD',
    0, 'bank', 'blue', 0, false,
    v_item_id, 'p2-core-a', 'depository', 'checking',
    NULL
  ) RETURNING id INTO v_acc;

  v_result := public.plaid_ensure_account_identity(v_user_id, v_acc);
  IF coalesce(v_result->>'status', '') <> 'created' THEN
    RAISE EXCEPTION 'P2-1: expected created, got %', v_result;
  END IF;
  v_can := (v_result->>'canonical_account_id')::uuid;

  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P2-2: membership not active';
  END IF;
  IF coalesce(v_result->>'role', '') <> 'authoritative' THEN
    RAISE EXCEPTION 'P2-3: role not authoritative';
  END IF;
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P2-4: expected exactly one active membership';
  END IF;
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_account_members m
    WHERE m.canonical_account_id = v_can AND m.unlinked_at IS NULL AND m.role = 'authoritative'
  ) <> 1 THEN
    RAISE EXCEPTION 'P2-5: expected one authority';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc AND m.unlinked_at IS NULL AND m.link_origin = 'sync_bootstrap'
  ) THEN
    RAISE EXCEPTION 'P2-6: link_origin not sync_bootstrap';
  END IF;

  -- ===== P2-7..P2-8 idempotent ensure =====
  SELECT count(*) INTO v_canons_before
  FROM public.plaid_canonical_financial_accounts c WHERE c.user_id = v_user_id;
  v_result2 := public.plaid_ensure_account_identity(v_user_id, v_acc);
  IF coalesce(v_result2->>'status', '') <> 'already_membered' THEN
    RAISE EXCEPTION 'P2-7: expected already_membered, got %', v_result2;
  END IF;
  IF (v_result2->>'canonical_account_id')::uuid IS DISTINCT FROM v_can THEN
    RAISE EXCEPTION 'P2-8: canonical changed on repeat ensure';
  END IF;
  SELECT count(*) INTO v_canons_after
  FROM public.plaid_canonical_financial_accounts c WHERE c.user_id = v_user_id;
  IF v_canons_after <> v_canons_before THEN
    RAISE EXCEPTION 'P2-8: second canonical created';
  END IF;

  -- ===== P2-11..15 fencing =====
  BEGIN
    PERFORM public.plaid_ensure_account_identity(NULL, v_acc);
    RAISE EXCEPTION 'P2-15: expected invalid_input for null user';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT ILIKE '%invalid_input%' THEN
      RAISE EXCEPTION 'P2-15: unexpected %', SQLERRM;
    END IF;
  END;

  BEGIN
    PERFORM public.plaid_ensure_account_identity(v_user_id, v_missing);
    RAISE EXCEPTION 'P2-14: expected account_not_found';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT ILIKE '%account_not_found%' THEN
      RAISE EXCEPTION 'P2-14: unexpected %', SQLERRM;
    END IF;
  END;

  BEGIN
    PERFORM public.plaid_ensure_account_identity(v_user_other, v_acc);
    RAISE EXCEPTION 'P2-13: expected account_not_found for foreign user';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT ILIKE '%account_not_found%' THEN
      RAISE EXCEPTION 'P2-13: unexpected %', SQLERRM;
    END IF;
  END;

  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P2 Manual', 'cash', 'USD',
    0, 'cash', 'green', 0, false
  ) RETURNING id INTO v_acc_manual;

  BEGIN
    PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_manual);
    RAISE EXCEPTION 'P2-12: manual must not bootstrap';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT ILIKE '%account_not_plaid%' THEN
      RAISE EXCEPTION 'P2-12: unexpected %', SQLERRM;
    END IF;
  END;
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_manual AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P2-12: manual got membership';
  END IF;

  -- ===== P2-16..18 existing membership preserved =====
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived,
    plaid_item_id, plaid_account_id, plaid_type, plaid_subtype
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P2 Secondary', 'bank', 'USD',
    0, 'bank', 'blue', 0, false,
    v_item_id, 'p2-sec-b', 'depository', 'checking'
  ) RETURNING id INTO v_acc_b;
  INSERT INTO public.plaid_canonical_financial_accounts (user_id)
  VALUES (v_user_id) RETURNING id INTO v_can_b;
  -- A already auth on v_can; add B as secondary on same can — need A on can_b as auth first
  -- Reset: make B singleton secondary illegally? Better: create can with B secondary and A as auth
  -- Use separate can with only secondary: malformed. For P2-17 use: can with A auth, B secondary.
  DELETE FROM public.plaid_canonical_financial_account_members WHERE account_id = v_acc_b;
  -- Put A as auth on can_b and B secondary
  -- A already has membership on v_can — cannot have two active memberships.
  -- Create fresh pair:
  -- Drop approach: create acc_auth + acc_sec on new can
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived,
    plaid_item_id, plaid_account_id, plaid_type, plaid_subtype
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P2 Auth Host', 'bank', 'USD',
    0, 'bank', 'blue', 0, false,
    v_item_id, 'p2-auth-host', 'depository', 'checking'
  ) RETURNING id INTO v_acc;
  INSERT INTO public.plaid_canonical_financial_accounts (user_id)
  VALUES (v_user_id) RETURNING id INTO v_can;
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin
  ) VALUES (
    v_user_id, v_can, v_acc, 'authoritative', 'user_confirmed'
  );
  INSERT INTO public.plaid_canonical_financial_account_members (
    user_id, canonical_account_id, account_id, role, link_origin
  ) VALUES (
    v_user_id, v_can, v_acc_b, 'secondary', 'user_confirmed'
  );

  v_result := public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  IF coalesce(v_result->>'status', '') <> 'already_membered' THEN
    RAISE EXCEPTION 'P2-17: expected already_membered for secondary, got %', v_result;
  END IF;
  IF coalesce(v_result->>'role', '') <> 'secondary' THEN
    RAISE EXCEPTION 'P2-17: secondary promoted';
  END IF;
  IF (v_result->>'canonical_account_id')::uuid IS DISTINCT FROM v_can THEN
    RAISE EXCEPTION 'P2-18: secondary canonical changed';
  END IF;

  v_result := public.plaid_ensure_account_identity(v_user_id, v_acc);
  IF coalesce(v_result->>'status', '') <> 'already_membered'
     OR coalesce(v_result->>'role', '') <> 'authoritative' THEN
    RAISE EXCEPTION 'P2-16: authoritative not preserved %', v_result;
  END IF;

  -- ===== P2-19 P1 merge topology unchanged by ensure =====
  -- Create two singletons then merge via P1; ensure both afterward
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived,
    plaid_item_id, plaid_account_id, plaid_type, plaid_subtype, persistent_account_id
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P2 M A', 'bank', 'USD',
    0, 'bank', 'blue', 0, false,
    v_item_id, 'p2-m-a2', 'depository', 'checking', 'pai-m2'
  ) RETURNING id INTO v_acc;
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived,
    plaid_item_id, plaid_account_id, plaid_type, plaid_subtype, persistent_account_id
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P2 M B', 'bank', 'USD',
    0, 'bank', 'blue', 0, false,
    v_item_id, 'p2-m-b2', 'depository', 'checking', 'pai-m2'
  ) RETURNING id INTO v_acc_b;

  v_result := public.plaid_ensure_account_identity(v_user_id, v_acc);
  v_can := (v_result->>'canonical_account_id')::uuid;
  v_result := public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  v_can_b := (v_result->>'canonical_account_id')::uuid;
  v_result := public.plaid_link_canonical_financial_accounts(
    v_user_id, v_acc, v_acc_b, v_acc);
  IF coalesce(v_result->>'status', '') <> 'merged' THEN
    RAISE EXCEPTION 'P2-19 setup merge failed %', v_result;
  END IF;
  v_can := (v_result->>'canonical_account_id')::uuid;
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc);
  PERFORM public.plaid_ensure_account_identity(v_user_id, v_acc_b);
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id IN (v_acc, v_acc_b) AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P2-19: ensure broke merged topology';
  END IF;
  IF (
    SELECT m.role FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc AND m.unlinked_at IS NULL
  ) IS DISTINCT FROM 'authoritative'
     OR (
    SELECT m.role FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL
  ) IS DISTINCT FROM 'secondary' THEN
    RAISE EXCEPTION 'P2-19: merge roles changed by ensure';
  END IF;

  -- ===== P2-26..30 persist wiring =====
  SELECT count(*) INTO v_canons_before
  FROM public.plaid_canonical_financial_accounts c WHERE c.user_id = v_user_id;

  v_synced := public.plaid_persist_accounts_sync(
    v_user_id,
    v_item_id,
    'ins_test',
    'P2 Bank',
    null,
    null,
    null,
    now(),
    jsonb_build_array(
      jsonb_build_object(
        'plaid_account_id', 'p2-persist-new',
        'name', 'Persist New',
        'plaid_type', 'depository',
        'plaid_subtype', 'checking',
        'currency_code', 'USD',
        'current_balance', 1,
        'available_balance', 1,
        'persistent_account_id', 'pai-persist-new'
      )
    )
  );
  IF v_synced <> 1 THEN
    RAISE EXCEPTION 'P2-27: synced_count=%', v_synced;
  END IF;
  SELECT a.id INTO v_acc
  FROM public.accounts a
  WHERE a.user_id = v_user_id AND a.plaid_account_id = 'p2-persist-new';
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc AND m.unlinked_at IS NULL AND m.role = 'authoritative'
      AND m.link_origin = 'sync_bootstrap'
  ) THEN
    RAISE EXCEPTION 'P2-27: INSERT path missing singleton';
  END IF;

  -- existing unmembered then UPDATE path
  INSERT INTO public.accounts (
    id, user_id, name, type, currency_code,
    initial_balance, icon_key, color_key, sort_order, is_archived,
    plaid_item_id, plaid_account_id, plaid_type, plaid_subtype
  ) VALUES (
    gen_random_uuid(), v_user_id, 'P2 Preexist', 'bank', 'USD',
    0, 'bank', 'blue', 0, false,
    v_item_id, 'p2-preexist', 'depository', 'checking'
  ) RETURNING id INTO v_acc_b;
  IF EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL
  ) THEN
    RAISE EXCEPTION 'P2-28 setup: unexpected membership';
  END IF;

  SELECT count(*) INTO v_canons_before
  FROM public.plaid_canonical_financial_accounts c WHERE c.user_id = v_user_id;
  v_synced := public.plaid_persist_accounts_sync(
    v_user_id, v_item_id, 'ins_test', 'P2 Bank', null, null, null, now(),
    jsonb_build_array(
      jsonb_build_object(
        'plaid_account_id', 'p2-preexist',
        'name', 'P2 Preexist Updated',
        'plaid_type', 'depository',
        'plaid_subtype', 'checking',
        'currency_code', 'USD',
        'current_balance', 2,
        'available_balance', 2
      )
    )
  );
  IF v_synced <> 1 THEN
    RAISE EXCEPTION 'P2-28: sync failed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL AND m.role = 'authoritative'
  ) THEN
    RAISE EXCEPTION 'P2-28: UPDATE path did not bootstrap';
  END IF;
  SELECT m.canonical_account_id INTO v_can
  FROM public.plaid_canonical_financial_account_members m
  WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL;

  -- P2-9/P2-29/P2-10 repeat persist / metadata
  SELECT count(*) INTO v_canons_before
  FROM public.plaid_canonical_financial_accounts c WHERE c.user_id = v_user_id;
  PERFORM public.plaid_persist_accounts_sync(
    v_user_id, v_item_id, 'ins_test', 'P2 Bank', null, null, null, now(),
    jsonb_build_array(
      jsonb_build_object(
        'plaid_account_id', 'p2-preexist',
        'name', 'P2 Preexist Renamed',
        'plaid_type', 'depository',
        'plaid_subtype', 'checking',
        'currency_code', 'USD',
        'current_balance', 3,
        'available_balance', 3
      )
    )
  );
  SELECT count(*) INTO v_canons_after
  FROM public.plaid_canonical_financial_accounts c WHERE c.user_id = v_user_id;
  IF v_canons_after <> v_canons_before THEN
    RAISE EXCEPTION 'P2-9/P2-29: duplicate canonical on repeat persist';
  END IF;
  IF (
    SELECT m.canonical_account_id
    FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL
  ) IS DISTINCT FROM v_can THEN
    RAISE EXCEPTION 'P2-10: metadata update changed canonical';
  END IF;
  IF (
    SELECT count(*) FROM public.plaid_canonical_financial_account_members m
    WHERE m.account_id = v_acc_b AND m.unlinked_at IS NULL
  ) <> 1 THEN
    RAISE EXCEPTION 'P2-23: duplicate active membership';
  END IF;

  -- ===== P2-31..34 same-PAI non-merge =====
  v_synced := public.plaid_persist_accounts_sync(
    v_user_id, v_item_id, 'ins_test', 'P2 Bank', null, null, null, now(),
    jsonb_build_array(
      jsonb_build_object(
        'plaid_account_id', 'p2-pai-a',
        'name', 'PAI A',
        'plaid_type', 'depository',
        'currency_code', 'USD',
        'current_balance', 1,
        'persistent_account_id', 'pai-same-p2'
      ),
      jsonb_build_object(
        'plaid_account_id', 'p2-pai-b',
        'name', 'PAI B',
        'plaid_type', 'depository',
        'currency_code', 'USD',
        'current_balance', 1,
        'persistent_account_id', 'pai-same-p2'
      )
    )
  );
  IF v_synced <> 2 THEN
    RAISE EXCEPTION 'P2-31 setup sync failed';
  END IF;
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    JOIN public.accounts a ON a.id = m.account_id
    WHERE a.plaid_account_id IN ('p2-pai-a', 'p2-pai-b')
      AND m.unlinked_at IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'P2-31: same PAI siblings were merged by P2';
  END IF;

  -- different PAI remain separate (P2-33)
  PERFORM public.plaid_persist_accounts_sync(
    v_user_id, v_item_id, 'ins_test', 'P2 Bank', null, null, null, now(),
    jsonb_build_array(
      jsonb_build_object(
        'plaid_account_id', 'p2-pai-c',
        'name', 'PAI C',
        'plaid_type', 'depository',
        'currency_code', 'USD',
        'current_balance', 1,
        'persistent_account_id', 'pai-diff-c'
      ),
      jsonb_build_object(
        'plaid_account_id', 'p2-pai-d',
        'name', 'PAI D',
        'plaid_type', 'depository',
        'currency_code', 'USD',
        'current_balance', 1,
        'persistent_account_id', 'pai-diff-d'
      )
    )
  );
  IF (
    SELECT count(DISTINCT m.canonical_account_id)
    FROM public.plaid_canonical_financial_account_members m
    JOIN public.accounts a ON a.id = m.account_id
    WHERE a.plaid_account_id IN ('p2-pai-c', 'p2-pai-d')
      AND m.unlinked_at IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'P2-33: different PAI not separate';
  END IF;

  -- null PAI still singleton (P2-34) — already covered by core + preexist

  -- ===== P2-35..37 Stage F v2 identity helper =====
  IF public.plaid_internal_transfer_pai_different_proven(NULL, 'x') THEN
    RAISE EXCEPTION 'P2-35: null PAI should not prove different';
  END IF;
  IF public.plaid_internal_transfer_pai_different_proven('same', 'same') THEN
    RAISE EXCEPTION 'P2-36: same PAI should not prove different';
  END IF;
  IF NOT public.plaid_internal_transfer_pai_different_proven('a', 'b') THEN
    RAISE EXCEPTION 'P2-37: different PAI should prove';
  END IF;

  -- P2-30 signature: persist still (uuid,uuid,text,text,text,text,text,timestamptz,jsonb) → integer
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'plaid_persist_accounts_sync'
      AND pg_get_function_identity_arguments(p.oid)
        = 'p_user_id uuid, p_connection_id uuid, p_plaid_institution_id text, p_institution_name text, p_logo_base64 text, p_primary_color text, p_url text, p_balance_fetched_at timestamp with time zone, p_accounts jsonb'
  ) THEN
    -- argument names may omit in identity args; check types only
    IF (
      SELECT pg_get_function_identity_arguments(p.oid)
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'plaid_persist_accounts_sync'
    ) NOT LIKE 'uuid, uuid, text, text, text, text, text, timestamp with time zone, jsonb' THEN
      RAISE EXCEPTION 'P2-30: persist signature changed: %', (
        SELECT pg_get_function_identity_arguments(p.oid)
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'plaid_persist_accounts_sync'
      );
    END IF;
  END IF;

  -- P2-24/25 structural: ensure creates both in one function body without catch of unique_violation
  IF v_def_ensure ~* 'exception[[:space:]]+when[[:space:]]+unique_violation' THEN
    RAISE EXCEPTION 'P2-25: ensure catches unique_violation (orphan risk)';
  END IF;

END;
$$;

SELECT 'IDENTITY_P2_VALIDATION_PASS'
  AS identity_p2_validation_result;

ROLLBACK;
