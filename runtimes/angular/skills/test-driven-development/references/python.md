# Python TDD Reference

Test patterns, dependencies, and conventions for TDD in Python applications using pytest.

## Test Framework

Use **pytest** as the primary test framework. It provides concise syntax, powerful fixtures, and a rich plugin ecosystem.

## Test Layer Guide

| Layer | Tool | Use Case |
|-------|------|----------|
| Unit | `pytest` + `unittest.mock` / `pytest-mock` | Business logic with mocked dependencies |
| Integration | `pytest` + fixtures + real resources | Database, file system, or service interactions |
| API / E2E | `pytest` + framework test client | Full request-response through the application |

### Framework-Specific Test Clients

| Framework | Test Client |
|-----------|-------------|
| FastAPI | `from fastapi.testclient import TestClient` |
| Flask | `app.test_client()` |
| Django | `from django.test import Client` |

## Dependencies

### requirements-test.txt

```text
pytest>=7.0
pytest-mock>=3.10
pytest-cov>=4.0
```

### pyproject.toml (alternative)

```toml
[project.optional-dependencies]
test = [
    "pytest>=7.0",
    "pytest-mock>=3.10",
    "pytest-cov>=4.0",
]
```

## Naming Conventions

- Test files: `test_{module}.py`
- Test functions: `test_should_{expected_behavior}_when_{condition}()`
- Test classes (optional): `TestClassName`
- Fixtures: descriptive names in `conftest.py`

## Directory Structure

```
project/
├── src/
│   └── myapp/
│       ├── __init__.py
│       ├── service.py
│       └── repository.py
├── tests/
│   ├── conftest.py          # Shared fixtures
│   ├── unit/
│   │   ├── test_service.py
│   │   └── test_repository.py
│   └── integration/
│       └── test_api.py
├── pyproject.toml
└── requirements-test.txt
```

## Build & Test Commands

```bash
pytest                              # Run all tests
pytest tests/unit/                  # Run unit tests only
pytest tests/integration/           # Run integration tests only
pytest -k "test_create_user"        # Run tests matching name pattern
pytest --cov=src --cov-report=html  # Run with coverage report
pytest -x                           # Stop on first failure
pytest -v                           # Verbose output
```

## Test Patterns

### Unit Test — Service Layer

```python
from unittest.mock import MagicMock
from myapp.service import UserService
from myapp.models import User


class TestUserService:

    def test_should_return_user_when_user_exists(self):
        # Arrange
        repo = MagicMock()
        repo.find_by_id.return_value = User(id=1, email="john@example.com", name="John Doe")
        service = UserService(repository=repo)

        # Act
        result = service.find_by_id(1)

        # Assert
        assert result is not None
        assert result.email == "john@example.com"
        repo.find_by_id.assert_called_once_with(1)

    def test_should_raise_when_user_not_found(self):
        # Arrange
        repo = MagicMock()
        repo.find_by_id.return_value = None
        service = UserService(repository=repo)

        # Act & Assert
        with pytest.raises(UserNotFoundException, match="99"):
            service.get_by_id(99)
```

### Unit Test — Using pytest-mock

```python
def test_should_create_user(mocker):
    # Arrange
    repo = mocker.Mock()
    repo.save.return_value = User(id=1, email="new@example.com", name="New User")
    service = UserService(repository=repo)

    # Act
    result = service.create(email="new@example.com", name="New User")

    # Assert
    assert result.id == 1
    repo.save.assert_called_once()
```

### Unit Test — Using monkeypatch

```python
def test_should_use_env_variable(monkeypatch):
    # Arrange
    monkeypatch.setenv("API_KEY", "test-key-123")

    # Act
    from myapp.config import get_api_key
    result = get_api_key()

    # Assert
    assert result == "test-key-123"
```

### Fixtures — conftest.py

```python
import pytest
from myapp.models import User


@pytest.fixture
def sample_user():
    return User(id=1, email="test@example.com", name="Test User")


@pytest.fixture
def mock_repository(mocker):
    return mocker.Mock()


@pytest.fixture
def user_service(mock_repository):
    from myapp.service import UserService
    return UserService(repository=mock_repository)
```

### Parametrized Tests

```python
import pytest


@pytest.mark.parametrize("email,valid", [
    ("user@example.com", True),
    ("user@test.org", True),
    ("invalid", False),
    ("", False),
    ("@no-local.com", False),
])
def test_should_validate_email(email, valid):
    from myapp.validators import is_valid_email
    assert is_valid_email(email) == valid
```

### API Test — FastAPI

```python
from fastapi.testclient import TestClient
from myapp.main import app


client = TestClient(app)


def test_should_return_user_when_get_by_id():
    # Act
    response = client.get("/api/users/1")

    # Assert
    assert response.status_code == 200
    assert response.json()["email"] == "john@example.com"


def test_should_return_404_when_user_not_found():
    # Act
    response = client.get("/api/users/999")

    # Assert
    assert response.status_code == 404


def test_should_create_user_when_valid_request():
    # Arrange
    payload = {"email": "new@example.com", "name": "New User"}

    # Act
    response = client.post("/api/users", json=payload)

    # Assert
    assert response.status_code == 201
    assert response.json()["id"] is not None
```

## pytest Cheat Sheet

```python
# Basic assertions
assert result == expected
assert result is not None
assert len(items) == 3
assert "substring" in text

# Exception assertions
with pytest.raises(ValueError, match="invalid"):
    do_something_invalid()

# Approximate comparisons
assert result == pytest.approx(3.14, abs=0.01)

# Skipping tests
@pytest.mark.skip(reason="Not implemented yet")
@pytest.mark.skipif(sys.platform == "win32", reason="Unix only")

# Marking expected failures
@pytest.mark.xfail(reason="Known bug #123")
```

## Mocking Cheat Sheet

```python
from unittest.mock import MagicMock, patch, call

# Creating mocks
mock = MagicMock()
mock.method.return_value = "result"
mock.method.side_effect = ValueError("boom")

# Patching (decorator)
@patch("myapp.service.repository")
def test_example(mock_repo):
    mock_repo.find_all.return_value = []

# Patching (context manager)
with patch("myapp.service.send_email") as mock_send:
    do_something()
    mock_send.assert_called_once_with("user@test.com")

# Verifying calls
mock.method.assert_called_once()
mock.method.assert_called_with(42)
mock.method.assert_not_called()
assert mock.method.call_count == 3
mock.method.assert_has_calls([call(1), call(2)])
```
