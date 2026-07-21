from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.core.config import get_settings
from app.models import Base


config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

database_url = get_settings().database_url
if not database_url:
    raise RuntimeError("DB_URL is not configured in BE/.env")
config.set_main_option("sqlalchemy.url", database_url.replace("%", "%%"))

target_metadata = Base.metadata


def include_object(object_, name, type_, reflected, compare_to):
    # PostgreSQL omits the default `public` schema from reflected FK targets,
    # while the shared metadata must qualify them for cross-file resolution.
    # FK changes are therefore handled explicitly in revision scripts.
    if type_ == "foreign_key_constraint":
        return False
    # The pre-Alembic support-amount pipeline has source columns in policies.
    # Preserve the entire legacy table even though it is intentionally absent
    # from the application ORM metadata.
    if (
        reflected
        and compare_to is None
        and (
            (type_ == "table" and name == "policies")
            or getattr(getattr(object_, "table", None), "name", None) == "policies"
        )
    ):
        return False
    return not getattr(object_, "info", {}).get("external", False)


def include_name(name, type_, parent_names):
    if type_ == "schema":
        return name in (None, "public")
    if type_ == "table":
        return parent_names.get("schema_name") in (None, "public")
    return True


def run_migrations_offline() -> None:
    context.configure(
        url=database_url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_schemas=True,
        include_object=include_object,
        include_name=include_name,
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_schemas=True,
            include_object=include_object,
            include_name=include_name,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
