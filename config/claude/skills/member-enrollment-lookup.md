---
name: member-lookup
description: Look up a member by email and trace their enrollment chain across magichat, benefit-hub, and eligibility databases. Works from either the Peloton email or the eligibility/corporate email.
user-invocable: true
arguments:
  - name: email
    description: The member's email address to look up
    required: true
---

# Member Enrollment Lookup

Given a member email, trace their full enrollment chain across all three databases. The email provided may be the member's **Peloton account email** (personal) or their **eligibility/corporate email** — these are usually different. Try both paths to find the member.

## Path A: Starting from Peloton email (magichat)

Use this path when the email looks like a personal email (gmail, yahoo, etc.).

### A1. Find the member in magichat

Query `prod-magichat-read-only` (database: `magichat`):

```sql
SELECT pk, email, first_name, last_name, username
FROM peloton_user
WHERE email = '{{email}}'
```

- The `pk` field is the member ID (UUID format).
- If no result, try case-insensitive: `WHERE lower(email) = lower('{{email}}')`.
- If no result found, the email may be a corporate/eligibility email — skip to **Path B**.

### A2. Check for an enrollment in benefit hub

Query `prod-benefit-hub-1w-read-only` (database: `benefit_hub`):

```sql
SELECT e.id, e.access_token, e.member_id, e.program_id, e.eligibility_check, e.last_workout_at, p.name as program_name
FROM enrollments_enrollment e
JOIN benefits_program p ON e.program_id = p.id
WHERE e.member_id = '<member_id_without_hyphens>'
```

- **Important:** The benefit hub `member_id` stores the UUID **without hyphens** (e.g., `ddf00aa728594510a8941d2dfe30e5b2`).
- Note the `access_token` from the enrollment — this links to the eligibility service.

### A3. Check if the access token links to an eligible person

Query `prod-eligibility-1w-read-only` (database: `eligibility`):

First check the `eligibility_accesstoken` table (most reliable, since the person's `access_token` field rotates):

```sql
SELECT token, expiration_date, eligible_person_id, created
FROM eligibility_accesstoken
WHERE token = '<access_token_from_enrollment>'
```

Then look up the eligible person:

```sql
SELECT ep.id, ep.first_name, ep.last_name, ep.email_address, ep.access_token, ep.sponsor_id, ep.internal_id, ep.created, ep.modified
FROM eligibility_eligibleperson ep
WHERE ep.id = <eligible_person_id>
```

- Note: The eligible person's `email_address` will typically be a **corporate email**, different from the Peloton account email.
- Note whether the token is expired (`expiration_date` < now).

### A4. Check for an active eligibility period (corporate wellness discount)

Query `prod-eligibility-1w-read-only` (database: `eligibility`):

```sql
SELECT id, effective_date, termination_date, program_name, created, modified
FROM eligibility_eligibilityperiod
WHERE eligible_person_id = <eligible_person_id>
ORDER BY effective_date DESC
```

- **Active** = `termination_date` is NULL or in the future.
- **Inactive** = `termination_date` is in the past.

---

## Path B: Starting from eligibility/corporate email

Use this path when the email looks like a corporate/work email, or when Path A found no Peloton account.

### B1. Find the eligible person in eligibility

Query `prod-eligibility-1w-read-only` (database: `eligibility`):

```sql
SELECT id, first_name, last_name, email_address, access_token, sponsor_id, internal_id, created, modified
FROM eligibility_eligibleperson
WHERE email_address ILIKE '{{email}}'
```

- Note the `id` (eligible_person_id) and `sponsor_id`.

### B2. Look up the sponsor

```sql
SELECT id, name FROM eligibility_sponsor WHERE id = <sponsor_id>
```

### B3. Check for an active eligibility period

```sql
SELECT id, effective_date, termination_date, program_name, created, modified
FROM eligibility_eligibilityperiod
WHERE eligible_person_id = <eligible_person_id>
ORDER BY effective_date DESC
```

- **Active** = `termination_date` is NULL or in the future.
- **Inactive** = `termination_date` is in the past.

### B4. Get all access tokens for this person

```sql
SELECT token, expiration_date, eligible_person_id, created
FROM eligibility_accesstoken
WHERE eligible_person_id = <eligible_person_id>
ORDER BY created DESC
```

- Multiple short-lived tokens generated in a short period may indicate the user is repeatedly attempting to enroll.

### B5. Check if any access tokens have a benefit hub enrollment

Query `prod-benefit-hub-1w-read-only` (database: `benefit_hub`):

```sql
SELECT e.id, e.access_token, e.member_id, e.program_id, e.eligibility_check, e.last_workout_at, p.name as program_name
FROM enrollments_enrollment e
JOIN benefits_program p ON e.program_id = p.id
WHERE e.access_token IN ('<token1>', '<token2>', ...)
```

- Use all tokens from B4.
- If an enrollment exists, the `member_id` (UUID without hyphens) links to a Peloton account.

### B6. Look up the Peloton account (if enrollment found)

If an enrollment was found in B5, look up the member in magichat:

Query `prod-magichat-read-only` (database: `magichat`):

```sql
SELECT pk, email, first_name, last_name, username
FROM peloton_user
WHERE replace(pk::text, '-', '') = '<member_id_from_enrollment>'
```

Or re-insert hyphens into the member_id to match UUID format: `WHERE pk = '<member_id_as_uuid>'`

---

## Output

Summarize the findings clearly:

1. **Eligible Person** — name, corporate email, sponsor, internal ID from eligibility
2. **Eligibility Period** — whether they have an active period (corporate wellness discount), effective/termination dates
3. **Access Tokens** — list of tokens, their expiration status, any patterns (e.g., repeated attempts)
4. **Benefit Hub Enrollment** — whether one exists, program name, access token used
5. **Peloton Account** — email, member ID, username from magichat (if found)

Flag key issues:
- No Peloton account = user hasn't created one or used a different email
- No enrollment but active tokens = enrollment flow may be failing
- Expired tokens with no active ones = may need re-verification
- Multiple short-lived tokens in a short period = user likely struggling with enrollment flow
