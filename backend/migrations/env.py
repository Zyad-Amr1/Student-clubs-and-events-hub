from alembic import context
from alembic.util import CommandError
from sqlalchemy import create_engine
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.pool import NullPool

from app.config import DatabaseConfigurationError, get_database_url
from app.models.auth_session import AuthSession  # register table with shared Base metadata
from app.models.user import User


def run_migrations() -> None:
    # User.metadata is the shared Base metadata, with the users table registered.
    target_metadata = User.metadata
    if context.is_offline_mode():
        context.configure(dialect_name="postgresql", target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()
        return

    engine = create_engine(
        get_database_url(),
        connect_args={"connect_timeout": 3},
        poolclass=NullPool,
        hide_parameters=True,
    )
    try:
        with engine.connect() as connection:
            context.configure(connection=connection, target_metadata=target_metadata)
            with context.begin_transaction():
                context.run_migrations()
    finally:
        engine.dispose()


try:
    run_migrations()
except DatabaseConfigurationError:
    raise CommandError("Check the DATABASE_URL configuration.") from None
except ImportError:
    raise CommandError("The Psycopg PostgreSQL driver could not load.") from None
except SQLAlchemyError:
    raise CommandError("Database operation failed during migration.") from None
