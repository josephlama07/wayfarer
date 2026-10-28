# Database migrations

PostgreSQL is an optional educational Compose service and is deliberately unwired. localStorage is the correct MVP boundary while the product is single-user, offline-friendly, and has no server/API requirement.

Introduce PostgreSQL plus Prisma when multiple devices, accounts, shared workspaces, auditability, or server-side reporting become requirements. At that point, use reviewed, forward-only expand/contract migrations: add nullable/new structures first, deploy code that can read both shapes, backfill safely, switch reads/writes, then remove old columns in a later release. Never rewrite history or make an irreversible migration part of a routine deploy. CI should run Prisma validation and migration checks against an ephemeral database before promotion.
