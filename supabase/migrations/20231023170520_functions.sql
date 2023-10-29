create or replace function create_group(
    display_name text
)
    returns bigint
    language sql as
$$
with new_group as (insert into groups (display_name) values (create_group.display_name) returning id),
     new_member as (insert into members (group_id, profile_id, role_id) select id, auth.uid(), 1 from new_group)
select id
from new_group;
    -- TODO(borgoat): get admin role id from config
$$;
comment on function create_group(text) is 'Creates a group with the given display name and adds the current user as an admin';

create or replace function handle_new_user()
    returns trigger
    language plpgsql
    security definer set search_path = public
as
$$
begin
    insert into public.profiles (id)
    values (new.id);
    return new;
end;
$$;
comment on function handle_new_user() is 'Creates a profile for a new user';

create or replace trigger on_auth_user_created
    after insert
    on auth.users
    for each row
execute procedure public.handle_new_user();
comment on trigger on_auth_user_created on auth.users is 'Creates a profile whenever a new user is created';
