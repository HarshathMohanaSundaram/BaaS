# ADR 0003: Customers

Status: Accepted
Date: 2026-11-03

## Context

A customer is someone an organization bills. Subscriptions and invoices will reference customers, and
every customer belongs to exactly one organization. Nothing may link a customer to another
organization's data.

## Decisions

### Identity

- `external_id` is the organization's own identifier for the customer. It is required, may not be an
  empty string (`check_customers_external_id_not_empty`), and is unique per organization
  (`index_customers_on_organization_and_external_id`). Two organizations can use the same value.
- `stripe_customer_id` is optional and globally unique (`index_customers_on_stripe_customer_id`). Any
  number of customers can have none.
- `email` is required but not unique. One person can be a customer of several organizations, or appear
  twice within one.

### Payment type

`payment_type` is an integer enum (`credit_card: 0, bank_transfer: 1, cash: 2, check: 3`), defaulting
to `credit_card`. The database repeats the allowed values in `check_customers_payment_type_valid`,
so adding a value needs a migration as well as a model change.

### Account manager

A customer can have an account manager, who must be a user in the customer's organization.

- The database enforces this with a composite foreign key,
  `(account_manager_id, organization_id) → users (id, organization_id)` (`fk_customers_account_manager`),
  backed by the unique `(organization_id, id)` index on `users`. When `account_manager_id` is NULL
  Postgres skips the check, which is what makes the manager optional.
- The model association is keyed on `account_manager_id` **alone**. A composite `belongs_to` writes
  every column in its key on assignment, so assigning another organization's user silently moved the
  customer into that organization, and the foreign key couldn't catch it because both columns changed
  together. The model validates the same-organization rule instead, so the caller gets a readable error.
- The composite key also covers changes to `organization_id` alone: a customer can't move to another
  organization while it has a manager there, and a user can't move to another organization while
  managing customers.
- `index_customers_on_account_manager` on `(account_manager_id, organization_id)` covers the foreign key,
  so deleting or moving a user doesn't scan the whole table.

### References from other tables

The unique `(id, organization_id)` index (`index_customers_on_id_and_organization_id`) exists so that
future tables (subscriptions, invoices) can reference a customer with a composite foreign key and be
held to the customer's organization, the same way `customers` is held to its account manager's.
