
When(/^makes a call to a proxy$/) do
  response = @service_page.proxy.get('/')
  jor.wait_for_async_locks
  expect(response.code).to eq(200)
end
