Feature: Student club discovery
  Students can discover approved, active clubs and safely view their public details.

  Scenario: Approved Club Discovery
    Given an authenticated Student and clubs in mixed approval and activity states
    When the Student requests "GET /api/v1/clubs"
    Then only approved active clubs are returned with the public response schema

  Scenario: Unauthorized Access
    Given a caller without valid bearer credentials and a private club in the database
    When the caller requests "GET /api/v1/clubs" without an Authorization header
    Then the request is rejected without disclosing club data

  Scenario: Student Affairs Cannot Browse Clubs
    Given an authenticated Student Affairs account and a private club
    When the authenticated account requests "GET /api/v1/clubs"
    Then the request is forbidden without disclosing club data

  Scenario: Club Details Hide Nonpublic Events
    Given an authenticated Student, a visible club, and mixed event visibility states
    When the Student requests the visible club details
    Then only its approved published future events are returned with public fields

  Scenario: Hidden Clubs Are Not Disclosed
    Given an authenticated Student and clubs that must remain hidden
    When the Student requests each hidden club and a nonexistent club
    Then all responses are indistinguishable not-found results without private club data
