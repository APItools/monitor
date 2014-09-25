When(/^user goes to settings of that service$/) do
  @settings_page = @service_page.settings_page
end

Then(/^user can edit service by filling the form$/) do
  expect(@settings_page).to have_form
end
