Feature: Settings

  Users should be able to change their service settings


  Scenario: Visits settings page
    Given there is a service
     When user goes to settings of that service
     Then user can edit service by filling the form
