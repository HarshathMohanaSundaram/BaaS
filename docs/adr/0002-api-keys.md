# ADR 0002: API keys

Status: Accepted
Date: 2026-11-03

## Context

Organizations authenticate API requests with keys. A key is shown to the caller once, when it is
created, so a leaked database or log must not give anyone a usable key.

## Decisions

### Key format

A key is `pk_<8 random lowercase alphanumerics>.<secret>`, where the secret is
`SecureRandom.urlsafe_base64(24)` (192 random bits).

- The part before the dot is the `prefix`, stored in plaintext so a key can be shown and searched
  (`pk_a1b2c3d4…`) without revealing it.
- The prefix is random only. An earlier draft embedded the organization id, which would have told
  anyone holding a key our internal tenant ids and roughly how many tenants we have.
- The plaintext key is available as `ApiKey#token` on the instance that created it, and nowhere else.

### Digest and lookup

`digest` is the SHA-256 of the **full** token, prefix included, and verification looks keys up by
digest alone (`ApiKey.find_by_token`), through the unique index on `digest`.

- Because the prefix is part of what is hashed, a valid secret paired with another key's prefix
  matches nothing. There is no separate prefix check to forget.
- The prefix index is non-unique. It serves display and search only, and an 8-character prefix can
  collide across organizations without affecting verification.

### Plain SHA-256, not HMAC

The digest is plain SHA-256. HMAC-SHA256 with a server-side secret would mean a leaked database
alone can't be used to check guessed keys, but:

- the secret has 192 random bits, so guessing a key is infeasible with or without the server secret;
- an HMAC secret has to be stored, protected and rotated, and rotating it invalidates every key.

Revisit this if keys ever become shorter or user-chosen.

### Ownership

A key belongs to an organization and to the user who created it. Both are required (`user_id` is
`NOT NULL`), and the model validates that the user belongs to the key's organization. Unlike
`customers.account_manager_id`, this is not backed by a composite foreign key, so writes that skip
validations are not checked.
