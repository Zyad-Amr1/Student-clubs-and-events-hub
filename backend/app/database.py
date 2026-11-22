from collections.abc import Iterator
from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session

from app.config import get_database_url


class Base(DeclarativeBase):
    pass


@lru_cache(maxsize=1)
def get_engine() -> Engine:
    return create_engine(
        get_database_url(),
        connect_args={"connect_timeout": 3},
        pool_pre_ping=True,
        hide_parameters=True,
    )


def get_db() -> Iterator[Session]:
    """Yield a session for a request and close it on exit."""
    with Session(get_engine()) as session:
        yield session
