Given(/^there is a service$/) do
  service = home_page.add_service.select_demo('Echo').create
  @service_page = service.service_page
end

When(/^user sees all services$/) do
  navigation.services_listing
end

And(/^opens that service$/) do
  # TODO: extract this to helper / page object
  page.click_on(@service_page.name)
end
