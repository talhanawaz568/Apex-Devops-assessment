from unittest.mock import patch

from sqlalchemy.exc import OperationalError


# Test 1: Application Liveness

def test_liveness(client):

    response = client.get("/health")

    assert response.status_code == 200

    assert response.json() == {
        "status": "alive"
    }


# Test 2: Application Information

def test_root_version(client):

    response = client.get("/")

    assert response.status_code == 200

    assert response.json()["service"] == "apex-operations-api"


# Test 3: Database Readiness Success

def test_readiness_success(client):

    class FakeConnection:

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def execute(self, statement):
            return 1

    with patch(
        "app.main.engine.connect",
        return_value=FakeConnection()
    ):

        response = client.get("/ready")

    assert response.status_code == 200

    assert response.json()["database"] == "connected"


# Test 4: Database Readiness Failure

def test_readiness_database_down(client):

    with patch(
        "app.main.engine.connect",
        side_effect=OperationalError(
            "SELECT 1",
            {},
            Exception("database offline")
        )
    ):

        response = client.get("/ready")

    assert response.status_code == 503

    assert response.json()["status"] == "not_ready"


# Test 5: Create Task

def test_create_task(client):

    response = client.post(
        "/api/tasks",
        json={
            "title": "Check backup"
        }
    )

    assert response.status_code == 201

    assert response.json()["status"] == "pending"

    assert response.json()["id"] > 0


# Test 6: Retrieve Created Task

def test_get_created_task(client):

    create_response = client.post(
        "/api/tasks",
        json={
            "title": "Inspect service"
        }
    )

    task_id = create_response.json()["id"]

    response = client.get(
        f"/api/tasks/{task_id}"
    )

    assert response.status_code == 200

    assert response.json()["title"] == "Inspect service"


# Test 7: List Tasks

def test_list_tasks(client):

    client.post(
        "/api/tasks",
        json={"title": "A"}
    )

    client.post(
        "/api/tasks",
        json={"title": "B"}
    )

    response = client.get("/api/tasks")

    assert response.status_code == 200

    assert [
        task["title"]
        for task in response.json()
    ] == ["A", "B"]


# Test 8: Update Task

def test_update_task(client):

    create_response = client.post(
        "/api/tasks",
        json={"title": "Verify"}
    )

    task_id = create_response.json()["id"]

    response = client.patch(
        f"/api/tasks/{task_id}",
        json={
            "status": "completed"
        }
    )

    assert response.status_code == 200

    assert response.json()["status"] == "completed"


# Test 9: Reject Empty Task Title

def test_reject_blank_title(client):

    response = client.post(
        "/api/tasks",
        json={
            "title": ""
        }
    )

    assert response.status_code == 422


# Test 10: Reject Invalid Task Status

def test_reject_invalid_status(client):

    create_response = client.post(
        "/api/tasks",
        json={"title": "Task"}
    )

    task_id = create_response.json()["id"]

    response = client.patch(
        f"/api/tasks/{task_id}",
        json={
            "status": "unknown"
        }
    )

    assert response.status_code == 422


# Test 11: Nonexistent Task

def test_missing_task(client):

    response = client.get(
        "/api/tasks/999999"
    )

    assert response.status_code == 404
