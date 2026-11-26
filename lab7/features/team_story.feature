Feature: Student event reservations
  As a CampusConnect student
  I want to reserve places at student events
  So that I can attend events and get a place if an event is full

  Scenario: Reserve an event while seats are available
    Given an event has 2 seats available
    And student "2023001" has no reservation for the event
    When student "2023001" reserves a seat
    Then the reservation is confirmed
    And 1 seat remains available

  Scenario: Join the waitlist when an event is full
    Given an event has no seats available
    And student "2023002" has no reservation for the event
    When student "2023002" reserves a seat
    Then the reservation is added to the waitlist
    And the student is not marked as confirmed

  Scenario: Promote the first waiting student after cancellation
    Given an event is full
    And students "2023003" and "2023004" are waiting in that order
    When the confirmed student cancels the reservation
    Then student "2023003" is promoted to confirmed
    And student "2023004" remains first in the waitlist
