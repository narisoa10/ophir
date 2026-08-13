-- Stage H1: user-facing internal transfer review read model.
-- Adapter only. Does NOT modify Stage F/G mutation RPCs or state machine.
-- Flutter calls this via authenticated JWT (auth.uid()). Confirm/reverse remain
-- service_role Stage G RPCs invoked only through Edge Functions.

create or replace function public.plaid_list_internal_transfer_review_items(
    p_states text[] default array['candidate', 'confirmed']::text[]
)
returns table (
    reconciliation_id uuid,
    state text,
    transfer_operation_id uuid,
    amount numeric,
    currency_code text,
    outgoing_date date,
    incoming_date date,
    outgoing_account jsonb,
    incoming_account jsonb,
    outgoing_operation jsonb,
    incoming_operation jsonb,
    is_inconsistent boolean,
    inconsistency_code text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_state text;
begin
    if v_user_id is null then
        raise exception 'not_authenticated' using errcode = '42501';
    end if;

    if p_states is null or cardinality(p_states) = 0 then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    foreach v_state in array p_states
    loop
        if v_state is distinct from 'candidate'
           and v_state is distinct from 'confirmed'
        then
            raise exception 'invalid_input' using errcode = '22023';
        end if;
    end loop;

    return query
    select
        r.id as reconciliation_id,
        r.state,
        r.transfer_operation_id,
        case
            when r.state = 'confirmed'
                 and r.confirmed_snapshot is not null
                 and jsonb_typeof(r.confirmed_snapshot) = 'object'
              then nullif(r.confirmed_snapshot->>'amount', '')::numeric
            when r.evidence_snapshot is not null
                 and jsonb_typeof(r.evidence_snapshot) = 'object'
              then abs(nullif(r.evidence_snapshot->'outgoing'->>'amount', '')::numeric)
            else out_op.amount
        end as amount,
        case
            when r.state = 'confirmed'
                 and r.confirmed_snapshot is not null
                 and jsonb_typeof(r.confirmed_snapshot) = 'object'
              then nullif(btrim(coalesce(r.confirmed_snapshot->>'currency', '')), '')
            when r.evidence_snapshot is not null
                 and jsonb_typeof(r.evidence_snapshot) = 'object'
              then nullif(
                  btrim(coalesce(r.evidence_snapshot->'outgoing'->>'iso_currency_code', '')),
                  ''
              )
            else nullif(btrim(coalesce(out_op.currency_code::text, '')), '')
        end as currency_code,
        case
            when r.state = 'confirmed'
                 and r.confirmed_snapshot is not null
                 and jsonb_typeof(r.confirmed_snapshot) = 'object'
              then nullif(r.confirmed_snapshot->>'outgoing_date', '')::date
            when r.evidence_snapshot is not null
                 and jsonb_typeof(r.evidence_snapshot) = 'object'
              then nullif(r.evidence_snapshot->'outgoing'->>'date', '')::date
            else out_op.occurred_at
        end as outgoing_date,
        case
            when r.state = 'confirmed'
                 and r.confirmed_snapshot is not null
                 and jsonb_typeof(r.confirmed_snapshot) = 'object'
              then nullif(r.confirmed_snapshot->>'incoming_date', '')::date
            when r.evidence_snapshot is not null
                 and jsonb_typeof(r.evidence_snapshot) = 'object'
              then nullif(r.evidence_snapshot->'incoming'->>'date', '')::date
            else in_op.occurred_at
        end as incoming_date,
        jsonb_build_object(
            'id', coalesce(
                out_acc.id,
                case
                    when r.state = 'confirmed'
                         and r.confirmed_snapshot is not null
                      then nullif(r.confirmed_snapshot->>'outgoing_account_id', '')::uuid
                    else out_op.from_account_id
                end
            ),
            'display_name', out_acc.name,
            'mask', out_acc.mask,
            'available', (out_acc.id is not null)
        ) as outgoing_account,
        jsonb_build_object(
            'id', coalesce(
                in_acc.id,
                case
                    when r.state = 'confirmed'
                         and r.confirmed_snapshot is not null
                      then nullif(r.confirmed_snapshot->>'incoming_account_id', '')::uuid
                    else in_op.from_account_id
                end
            ),
            'display_name', in_acc.name,
            'mask', in_acc.mask,
            'available', (in_acc.id is not null)
        ) as incoming_account,
        case
            when out_op.id is null then null
            else jsonb_build_object(
                'id', out_op.id,
                'note', out_op.note,
                'amount', out_op.amount,
                'type', out_op.type,
                'occurred_at', out_op.occurred_at,
                'archived', (out_op.archived_at is not null)
            )
        end as outgoing_operation,
        case
            when in_op.id is null then null
            else jsonb_build_object(
                'id', in_op.id,
                'note', in_op.note,
                'amount', in_op.amount,
                'type', in_op.type,
                'occurred_at', in_op.occurred_at,
                'archived', (in_op.archived_at is not null)
            )
        end as incoming_operation,
        (r.inconsistent_at is not null) as is_inconsistent,
        r.inconsistency_code
    from public.plaid_internal_transfer_reconciliations as r
    left join public.operations as out_op
      on out_op.id = r.outgoing_operation_id
     and out_op.user_id = r.user_id
    left join public.operations as in_op
      on in_op.id = r.incoming_operation_id
     and in_op.user_id = r.user_id
    left join public.accounts as out_acc
      on out_acc.id = coalesce(
            case
                when r.state = 'confirmed'
                     and r.confirmed_snapshot is not null
                     and jsonb_typeof(r.confirmed_snapshot) = 'object'
                  then nullif(r.confirmed_snapshot->>'outgoing_account_id', '')::uuid
                else null
            end,
            out_op.from_account_id
         )
     and out_acc.user_id = r.user_id
    left join public.accounts as in_acc
      on in_acc.id = coalesce(
            case
                when r.state = 'confirmed'
                     and r.confirmed_snapshot is not null
                     and jsonb_typeof(r.confirmed_snapshot) = 'object'
                  then nullif(r.confirmed_snapshot->>'incoming_account_id', '')::uuid
                else null
            end,
            in_op.from_account_id
         )
     and in_acc.user_id = r.user_id
    where r.user_id = v_user_id
      and r.state = any (p_states)
    order by r.candidate_detected_at desc, r.id;
end;
$$;

comment on function public.plaid_list_internal_transfer_review_items(text[]) is
    'Stage H1 user-facing review list. auth.uid() fencing. Returns display-safe candidate/confirmed rows only. No projection/canonical/PFC/evidence/snapshot leakage. No mutations.';

revoke all on function public.plaid_list_internal_transfer_review_items(text[])
from public;
revoke all on function public.plaid_list_internal_transfer_review_items(text[])
from anon;
grant execute on function public.plaid_list_internal_transfer_review_items(text[])
to authenticated;
grant execute on function public.plaid_list_internal_transfer_review_items(text[])
to service_role;
