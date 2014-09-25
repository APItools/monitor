When(/^the landing page is loaded$/) do
  @home_page = home_page
end

When(/^the user wants to create new service$/) do
  @new_service_page = @home_page.add_service
end

Then(/^there should be a welcome page$/) do
  expect(@home_page).to have_welcome_page
end

Then(/^there should be a service dashboard$/) do
  expect(@home_page).to have_service_dashboard
end

Then(/^there should be a service dashboard empty$/) do
  expect(@home_page).to have_service_dashboard_empty
end

module HomePageHelper
  def home_page
    HomePage.new
  end
end

World(HomePageHelper)
