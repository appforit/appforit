drop table if exists replies;
drop table if exists default_replies;
drop table if exists schedules;
drop table if exists invites;
drop table if exists members;
drop table if exists groups;
drop table if exists profiles;
drop type if exists invite_methods;
drop type if exists reply_options;
drop domain if exists rfc7265;

create type reply_options as enum ('yes', 'no');
comment on type reply_options is 'Valid replies that users may select.';

create type invite_methods as enum ('email', 'phone', 'code');
comment on type invite_methods is 'The available strategies to invite a new user';

create type group_roles as enum ('admin', 'member'); -- TODO owner, read-only, guest ?
comment on type group_roles is 'The valid roles for group members.';

-- TODO handle validation, optional extensions
create domain rfc7265 as jsonb;
comment on domain rfc7265 is 'An alias for RFC7265 jCal (JSON) recurrence rule definitions.';

create table profiles
(
    id           uuid                                                          not null references auth.users on delete cascade primary key,
    created_at   timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at   timestamp with time zone default timezone('utc'::text, now()) not null,

    display_name text,
    picture      text
);
comment on table profiles is 'User profiles that apply across multiple groups.';
comment on column profiles.display_name is 'The user name, as seen by other users.';
comment on column profiles.picture is 'A URL to the user profile picture.';

create table groups
(
    id           bigint generated always as identity primary key,
    created_at   timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at   timestamp with time zone default timezone('utc'::text, now()) not null,

    display_name text                                                          not null,
    description  text,
    picture      text
);
comment on table groups is 'Group of users that share roles, schedules, replies.';
comment on column groups.display_name is 'The group name.';
comment on column groups.description is 'A description of the group.';
comment on column groups.picture is 'A URL to the group picture.';

create table members
(
    id                    bigint generated always as identity primary key,
    created_at            timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at            timestamp with time zone default timezone('utc'::text, now()) not null,

    group_id              bigint                                                        not null references groups on delete cascade,
    profile_id            uuid references profiles on delete cascade,

    -- TODO a group should be able to insert a profile with default replies before it even exists...
    --      therefore, we need a way to "invite" new members, so that when users sign up,
    --      they become owners of their own member_ids, and can override replies

    role                  group_roles                                                   not null default 'member'::group_roles,
    display_name_override text,

    unique (group_id, profile_id),

    -- if there's no profile linked yet, a display name must be set
    -- a user may also override their display name as members of a specific group
    constraint must_have_display_name_or_profile
        check (display_name_override is not null or profile_id is not null)
);
comment on table members is 'Define invitees and user membership in groups.';
comment on column members.display_name_override is 'In case a user wants to be known by another name in that specific group.';

create table invites
(
    id         bigint generated always as identity primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,

    member_id  bigint                                                        not null references members on delete cascade,

    method     invite_methods                                                not null,
    value      text                                                          not null

);
comment on table invites is 'Invites define a mapping for new users, to become members of groups.';

create unique index if_code_invite_unique
    on invites (value)
    where method = 'code'::invite_methods;
comment on index if_code_invite_unique is 'When is a code invite, the value must be unique.';

create index invites_method_values on invites (method, value);
comment on index invites_method_values is 'Index for invites, to find by method and value.';

create table schedules
(
    id              bigint generated always as identity primary key,
    created_at      timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at      timestamp with time zone default timezone('utc'::text, now()) not null,

    group_id        bigint                                                        not null references groups on delete cascade,

    display_name    text                                                          not null,
    start_date      timestamp with time zone                                      not null,
    recurrence_rule rfc7265                                                       not null
    -- TODO duration, end_date, timezone, etc
);
comment on table schedules is 'Schedules are a series of events within a group.';
comment on column schedules.display_name is 'A name for the schedule';
comment on column schedules.start_date is 'The first occurrence of the schedule.';
comment on column schedules.recurrence_rule is 'The rrule that defines when events are scheduled.';

create table default_replies
(
    created_at      timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at      timestamp with time zone default timezone('utc'::text, now()) not null,

    member_id       bigint                                                        not null references members on delete cascade,
    schedule_id     bigint                                                        not null references schedules on delete cascade,

    selected_option reply_options                                                 not null,
    recurrence_rule rfc7265                                                       not null,

    primary key (member_id, schedule_id)
);
comment on table default_replies is 'The default replies for each member, per schedule.';
comment on column default_replies.recurrence_rule is 'Must be equal or a subset of the corresponding schedule rule.';

create table replies
(
    created_at      timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at      timestamp with time zone default timezone('utc'::text, now()) not null,

    member_id       bigint                                                        not null references members on delete cascade,
    schedule_id     bigint                                                        not null references schedules on delete cascade,
    event_date      timestamp with time zone                                      not null,

    selected_option reply_options                                                 not null,

    primary key (member_id, schedule_id, event_date)
);
create index replies_event_date on replies (event_date);
comment on table replies is 'Override the default replies set per schedule/profile.';
comment on column replies.member_id is 'The member (either with a related profile or not) that overrides their default reply.';
comment on column replies.event_date is 'Defines the actual occurrence for the override reply.';
comment on index replies_event_date is 'Index for replies, to find by event_date.';

create extension if not exists moddatetime schema extensions;

create trigger handle_profiles_updated_at
    before update
    on profiles
    for each row
execute procedure moddatetime(updated_at);
create trigger handle_groups_updated_at
    before update
    on groups
    for each row
execute procedure moddatetime(updated_at);
create trigger handle_invites_updated_at
    before update
    on invites
    for each row
execute procedure moddatetime(updated_at);
create trigger handle_members_updated_at
    before update
    on members
    for each row
execute procedure moddatetime(updated_at);
create trigger handle_schedules_updated_at
    before update
    on schedules
    for each row
execute procedure moddatetime(updated_at);
create trigger handle_default_replies_updated_at
    before update
    on default_replies
    for each row
execute procedure moddatetime(updated_at);
create trigger handle_replies_updated_at
    before update
    on replies
    for each row
execute procedure moddatetime(updated_at);


alter table profiles
    enable row level security;
alter table groups
    enable row level security;
alter table invites
    enable row level security;
alter table members
    enable row level security;
alter table schedules
    enable row level security;
alter table default_replies
    enable row level security;
alter table replies
    enable row level security;

create or replace function is_member_of_group(
    check_group_id bigint,
    with_role group_roles[] default '{admin, member}'::group_roles[])
    returns boolean
    security definer set search_path = public
    language plpgsql stable
as
$$
begin
    return exists (select 1
                   from members
                   where profile_id = auth.uid()
                     and group_id = is_member_of_group.check_group_id
                     and role = any (is_member_of_group.with_role));
end;
$$;
comment on function is_member_of_group(bigint, group_roles[]) is 'Check if the current user is a member of a group, with a specific role.';

create policy "profiles_select"
    on profiles
    for select
    to authenticated
    using ((select auth.uid()) = id);
comment on policy "profiles_select" on profiles is 'Users can see their own profile';

create policy "profiles_update"
    on profiles
    for update
    to authenticated
    using ((select auth.uid()) = id)
    with check ((select auth.uid()) = id);
comment on policy "profiles_update" on profiles is 'Users can update their own profile';

create policy "groups_select"
    on groups
    for select
    to authenticated
    using (is_member_of_group(id));

create policy "groups_update"
    on groups
    for update
    to authenticated
    using (is_member_of_group(id, '{admin}'::group_roles[]))
    with check (is_member_of_group(id, '{admin}'::group_roles[]));
comment on policy "groups_update" on groups is 'Admins can update groups';

create policy "groups_delete"
    on groups
    for delete
    to authenticated
    using (is_member_of_group(id, '{admin}'::group_roles[]));
comment on policy "groups_delete" on groups is 'Admins can delete groups';

create policy "members_select"
    on members
    for select
    to authenticated
    using (is_member_of_group(group_id));
comment on policy "members_select" on members is 'Users can see members of groups they are members of';

create policy "members_all"
    on members
    for all
    to authenticated
    using (is_member_of_group(members.group_id, '{admin}'::group_roles[]))
    with check (is_member_of_group(members.group_id, '{admin}'::group_roles[]));
comment on policy "members_all" on members is 'Admins can manage group members';

create policy "invites_all"
    on invites
    for all
    to authenticated
    using (is_member_of_group((select group_id
                               from members
                               where id = invites.member_id), '{admin}'::group_roles[]))
    with check (is_member_of_group((select group_id
                                    from members
                                    where id = invites.member_id), '{admin}'::group_roles[]));
comment on policy "invites_all" on invites is 'Admins can add and manage invites for new group members';

create policy "schedules_select"
    on schedules
    for select
    to authenticated
    using (is_member_of_group(group_id));
comment on policy "schedules_select" on schedules is 'Users can see schedules of groups they are members of';

create policy "schedules_all"
    on schedules
    for all
    to authenticated
    using (is_member_of_group(schedules.group_id, '{admin}'::group_roles[]))
    with check (is_member_of_group(schedules.group_id, '{admin}'::group_roles[]));
comment on policy "schedules_all" on schedules is 'Admins can manage schedules';

create policy "default_replies_select"
    on default_replies
    for select
    to authenticated
    using (is_member_of_group(
        (select group_id
         from schedules
         where id = schedule_id)));
comment on policy "default_replies_select" on default_replies is 'Users can see default replies of schedules of groups they are members of';

create policy "default_replies_all"
    on default_replies
    for all
    to authenticated
    using (is_member_of_group(
        (select group_id
         from schedules
         where id = default_replies.schedule_id), '{admin}'::group_roles[]))
    with check (is_member_of_group(
        (select group_id
         from schedules
         where id = default_replies.schedule_id), '{admin}'::group_roles[]));
comment on policy "default_replies_all" on default_replies is 'Admins can manage all default replies';

create policy "default_replies_all_self"
    on default_replies
    for all
    to authenticated
    using ((select auth.uid()) = (select profile_id
                                  from members
                                  where id = member_id))
    with check ((select auth.uid()) = (select profile_id
                                       from members
                                       where id = member_id));
comment on policy "default_replies_all_self" on default_replies is 'Users can manage their own default replies';

create policy "replies_select"
    on replies
    for select
    to authenticated
    using (is_member_of_group(
        (select group_id
         from schedules
         where id = schedule_id)));
comment on policy "replies_select" on replies is 'Users can see replies of schedules of groups they are members of';

create policy "replies_all"
    on replies
    for all
    to authenticated
    using (is_member_of_group(
        (select group_id
         from schedules
         where id = replies.schedule_id), '{admin}'::group_roles[]))
    with check (is_member_of_group(
        (select group_id
         from schedules
         where id = replies.schedule_id), '{admin}'::group_roles[]));
comment on policy "replies_all" on replies is 'Admins can manage all replies';

create policy "replies_all_self"
    on replies
    for all
    to authenticated
    using ((select auth.uid()) = (select profile_id
                                  from members
                                  where id = member_id))
    with check ((select auth.uid()) = (select profile_id
                                       from members
                                       where id = member_id));
comment on policy "replies_all_self" on replies is 'Users can manage their own replies';
