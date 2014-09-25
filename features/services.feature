Feature: Multiple Services
  In order to let users integrate with many services
  The users
  Should have a way to create multiple services

  Scenario: Service listing
    Given there is a service
    When user sees all services
     And opens that service
    Then it should see service traces
