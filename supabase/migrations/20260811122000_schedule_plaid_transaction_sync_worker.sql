create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

do $$
begin
    if not exists (
        select 1
        from vault.decrypted_secrets
        where vault.decrypted_secrets.name = 'ophir_worker_project_url'
          and trim(vault.decrypted_secrets.decrypted_secret) <> ''
    ) then
        raise exception 'ophir_worker_project_url_missing';
    end if;

    if not exists (
        select 1
        from vault.decrypted_secrets
        where vault.decrypted_secrets.name = 'ophir_internal_worker_secret'
          and trim(vault.decrypted_secrets.decrypted_secret) <> ''
    ) then
        raise exception 'ophir_internal_worker_secret_missing';
    end if;
end;
$$;

select cron.schedule(
    'ophir-process-plaid-transaction-sync-jobs',
    '* * * * *',
    $cron$
    do $$
    begin
        if not exists (
            select 1
            from vault.decrypted_secrets
            where vault.decrypted_secrets.name = 'ophir_worker_project_url'
              and trim(vault.decrypted_secrets.decrypted_secret) <> ''
        ) then
            raise exception 'ophir_worker_project_url_missing';
        end if;

        if not exists (
            select 1
            from vault.decrypted_secrets
            where vault.decrypted_secrets.name = 'ophir_internal_worker_secret'
              and trim(vault.decrypted_secrets.decrypted_secret) <> ''
        ) then
            raise exception 'ophir_internal_worker_secret_missing';
        end if;

        perform net.http_post(
            url := rtrim(
                (
                    select vault.decrypted_secrets.decrypted_secret
                    from vault.decrypted_secrets
                    where vault.decrypted_secrets.name = 'ophir_worker_project_url'
                ),
                '/'
            )
                || '/functions/v1/plaid-process-transaction-sync-jobs',
            headers := jsonb_build_object(
                'Content-Type',
                'application/json',
                'x-ophir-internal-secret',
                (
                    select vault.decrypted_secrets.decrypted_secret
                    from vault.decrypted_secrets
                    where vault.decrypted_secrets.name = 'ophir_internal_worker_secret'
                )
            ),
            body := '{}'::jsonb,
            timeout_milliseconds := 120000
        );
    end;
    $$;
    $cron$
);
