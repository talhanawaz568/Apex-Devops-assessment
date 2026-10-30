import pytest

from fastapi.testclient import TestClient

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import models  # noqa: F401
from app.database import Base, get_db
from app.main import app


@pytest.fixture
def client():

    # Create an isolated SQLite database for testing.
    test_engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    # Create application tables in the test database.
    Base.metadata.create_all(bind=test_engine)

    TestingSession = sessionmaker(
        bind=test_engine,
        expire_on_commit=False,
    )

    # Replace the real database dependency.
    def override_get_db():

        with TestingSession() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db

    try:
        # Avoid starting the production lifespan, which
        # initializes the real PostgreSQL database.
        yield TestClient(app)

    finally:

        # Remove dependency overrides after each test.
        app.dependency_overrides.clear()

        # Release test database resources.
        test_engine.dispose()
