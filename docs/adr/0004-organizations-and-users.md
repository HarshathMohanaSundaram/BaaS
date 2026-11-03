# ADR 0004: Organizations and users

Status: Accepted
Date: 2026-11-03

## Context

The app is multi-tenant. An organization is the tenant, and every other record (users, plans,
customers, API keys) belongs to exactly one organization.

## Decisions

### Organizations

- `email` is required and globally unique (`index_organizations_on_email_unique`). Uniqueness is
  enforced only by the database; the model has no validation for it.
- `currency_type` is an integer enum (`inr: 1, usd: 2, eur: 3`), repeated in the database as
  `currency_type_valid`. It starts at 1, so 0 is never a valid currency.
- Deleting an organization is blocked while anything references it: none of the foreign keys to
  `organizations` cascade.

### Users

- A user belongs to exactly one organization (`organization_id` is `NOT NULL`).
- `email` is globally unique, in the model and in the database (`index_users_on_email_unique`). One
  email address can therefore only ever belong to one organization.
- Passwords use `has_secure_password` (bcrypt); only `password_digest` is stored.
- Deleting a user through Rails destroys their API keys (`dependent: :destroy`). The database foreign
  key doesn't cascade, so a raw delete is blocked while keys exist, as it is while the user is a
  customer's account manager.

### Keeping records inside one organization

When a row references another tenant-owned row, both must be in the same organization. Two
techniques are in use:

- **Composite foreign key** (database-enforced): the referenced table gets a unique index that
  includes `organization_id`, and the referencing table points at it with
  `(<ref>_id, organization_id)`. Used by `plans.previous_plan_id` (ADR 0001) and
  `customers.account_manager_id` (ADR 0003). `users` has the unique `(organization_id, id)` index for
  this, which replaced the plain `organization_id` index.
- **Model validation only**: used by `api_keys.user_id` (ADR 0002). Writes that skip validations are
  not checked.

Prefer the composite foreign key for new references. Keep the Rails association keyed on the single
`<ref>_id` column and add a model validation for a readable error: a composite `belongs_to` overwrites
`organization_id` on assignment (see ADR 0003).

## Open questions

- `business_type` and `users.role` are plain integers with no enum or check constraint, so their
  allowed values aren't defined anywhere yet.
- `last_invoice_number` (default 0) isn't used by any code yet. If it becomes a per-organization
  invoice counter, it needs row locking when it is incremented, as plan versioning does.
