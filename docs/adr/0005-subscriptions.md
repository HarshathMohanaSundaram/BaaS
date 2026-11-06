# ADR 0005: Subscriptions

Status: Accepted
Date: 2026-11-06

## Context

A subscription puts a customer on a plan, within one organization. A customer must not be subscribed
to the same plan twice at once, including through different versions of it, and nothing may link a
subscription to another organization's data. Plans are versioned (ADR 0001), so "the same plan" means
the same lineage rather than the same plan row.

This ADR covers the table and the model. No service, job or API acts on subscriptions yet.

## Decisions

### Status

`status` is an integer enum (`trialing: 1, active: 2, past_due: 3, canceled: 4`) declared with
`validate: true`, so an unknown value is a validation error instead of an `ArgumentError`. The database
repeats the allowed values in `check_status_enum`, so adding a value needs a migration as well as a
model change.

`Subscription::LIVE_STATUSES` is `trialing`, `active` and `past_due`. A `past_due` subscription is still
live: it still holds the customer's place on the plan. Only `canceled` is terminal for uniqueness.

### One live subscription per customer and lineage

The partial unique index `index_live_unique_subscriptions_on_customer_id_and_lineage_key` covers
`(customer_id, lineage_key) WHERE status IN (1, 2, 3)`.

- `lineage_key` is copied onto the subscription because an index can't read another table's columns.
  `(plan_id, lineage_key) → plans (id, lineage_key)` (`fk_subscriptions_plan_lineage`) guarantees the copy
  matches the plan.
- Keying on the lineage rather than `plan_id` means a customer on v1 can't also take out a live
  subscription on v2. Moving to a new version has to update the existing subscription or cancel it first.
- Canceled rows are outside the index, so a customer can resubscribe and keep any number of canceled
  subscriptions as history.
- The model repeats the rule with a conditional uniqueness validation, so the caller gets a readable
  error. The index is what holds under concurrency, because two simultaneous requests can both pass the
  validation.

The index's status list and `LIVE_STATUSES` must change together. Changing which statuses are live needs
a migration that replaces the index.

### Organization consistency

- The database enforces it with composite foreign keys, `(customer_id, organization_id) → customers (id,
  organization_id)` (`fk_subscriptions_customer`) and `(plan_id, organization_id) → plans (id,
  organization_id)` (`fk_subscriptions_plan_organization`). They also stop a customer or plan moving to
  another organization while it has subscriptions.
- The model associations are keyed on `customer_id` and `plan_id` alone, for the reason given in ADR 0003:
  a composite `belongs_to` writes every column in its key on assignment, and would silently move the
  subscription into the other organization. The model validates the same-organization rules instead.
- `(customer_id, organization_id)` and `(plan_id, organization_id)` are indexed to cover the foreign keys.
  `fk_subscriptions_plan_lineage` has no index of its own and relies on the `plan_id` prefix.

### Subscribing to a plan

A new subscription must be on a live (unarchived) plan. The validation runs on create only, so existing
subscriptions stay valid when their plan is archived, which happens whenever a new version is created
(ADR 0001). They stay on the version they signed up for until something moves them.

### Cancellation

`canceled_at` is set if and only if the status is `canceled`, enforced by the model and by
`check_canceled_at_status_consistency`.

`cancel_at_period_end` is a separate boolean, defaulting to false. It records a pending cancellation on a
subscription that is still live, so it doesn't affect `status` or `canceled_at`. Nothing acts on it yet.

### Billing period

`current_period_end` must be strictly after `current_period_start`, enforced by the model and by
`check_current_period_end_after_start`. `trial_ends_at` is optional and has no rule tying it to `status`
or to the period.

### Deletion

Foreign keys block deleting an organization, customer or plan that has subscriptions. `Organization`,
`Customer` and `Plan` also declare `dependent: :restrict_with_error`, so `destroy` returns `false` with an
error.

## Known gaps

- **Moving to an archived plan:** because the live-plan validation runs on create only, an update can
  point an existing subscription at an archived plan. Whatever implements plan changes has to check this.
- **Losing the uniqueness race:** nothing rescues `ActiveRecord::RecordNotUnique` from the live index yet,
  so the losing request gets a raw exception. The service that creates subscriptions should translate it
  to `ConflictError`, as `Plan::Versioning` does for its unique index.
