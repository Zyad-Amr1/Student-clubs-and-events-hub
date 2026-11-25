import base64
from io import BytesIO

from PIL import Image

from test_user_postgresql import registration_body


def test_private_profile_and_password_change(auth_client):
    client = auth_client
    registration = registration_body()
    assert client.post("/api/v1/auth/register", json=registration).status_code == 201
    credentials = {"email": registration["email"], "password": registration["password"]}
    token = client.post("/api/v1/auth/login", json=credentials).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    assert client.get("/api/v1/auth/academic-catalog", headers=headers).status_code == 200
    assert client.get("/api/v1/auth/me/managed-clubs", headers=headers).json() == {"clubs": []}
    assert client.put("/api/v1/auth/me", json={"full_name": "New Name"}).status_code == 401
    update = {
        "full_name": "Updated Student",
        "faculty": "Science",
        "department": "Physics",
        "academic_year": 2,
    }
    assert client.put("/api/v1/auth/me", headers=headers, json={
        **update, "email": "other@example.edu",
    }).status_code == 422
    assert client.put("/api/v1/auth/me", headers=headers, json={
        **update, "department": "Accounting",
    }).status_code == 422
    assert client.put("/api/v1/auth/me", headers=headers, json={
        **update, "picture_base64": "aGVsbG8=",
    }).status_code == 422

    image = BytesIO()
    Image.new("RGB", (10, 10), "blue").save(image, format="PNG")
    result = client.put("/api/v1/auth/me", headers=headers, json={
        **update, "picture_base64": base64.b64encode(image.getvalue()).decode(),
    })
    assert result.status_code == 200, result.text
    profile = client.get("/api/v1/auth/me", headers=headers).json()
    assert {key: profile[key] for key in update} == update
    assert profile["profile_picture_url"].startswith("data:image/jpeg;base64,")
    assert client.put("/api/v1/auth/me", headers=headers, json=update).json()[
        "profile_picture_url"
    ] == profile["profile_picture_url"]
    assert client.put("/api/v1/auth/me", headers=headers, json={
        **update, "picture_base64": None,
    }).json()["profile_picture_url"] is None

    new = "ChangedPassword#42"
    change = {"current_password": credentials["password"], "new_password": new, "confirm_password": new}
    path = "/api/v1/auth/me/password"
    wrong = client.post(path, headers=headers, json={**change, "current_password": "incorrect"})
    assert wrong.status_code == 400
    invalid = client.post(path, headers=headers, json={**change, "confirm_password": "DifferentPassword"})
    assert invalid.status_code == 422 and new not in invalid.text
    assert client.post(path, headers=headers, json=change).status_code == 204
    assert client.post("/api/v1/auth/login", json=credentials).status_code == 401
    assert client.post("/api/v1/auth/login", json={**credentials, "password": new}).status_code == 200
    assert client.post("/api/v1/auth/logout", headers=headers).status_code == 204
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
