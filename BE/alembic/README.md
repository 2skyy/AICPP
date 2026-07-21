# Database migrations

Alembic reads `DB_URL` from `BE/.env`. Use the Supabase pooler connection
string with the psycopg SQLAlchemy driver, for example:

```dotenv
DB_URL=postgresql+psycopg://postgres.PROJECT_REF:PASSWORD@POOLER_HOST:6543/postgres?sslmode=require
```

From the `BE` directory:

```powershell
py -m alembic current
py -m alembic upgrade head
py -m alembic revision --autogenerate -m "describe change"
```

The first revision preserves the existing `public.policies` source table.
Revision `20260721_0002` creates `public.arranged_policies`, copies normalized
application data, and repoints application foreign keys. It never deletes the
2,646-row source table or its reviewed support-amount data.

Check the current database revision before applying changes:

```powershell
py -m alembic current
py -m alembic heads
```

The compatibility-aware first revision inspects the existing `policies`
table, so it must run in online mode and does not support `--sql`.

Do not commit `BE/.env` or place a Supabase service-role key in Flutter.
