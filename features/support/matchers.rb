require 'rspec/expectations'

RSpec::Matchers.define :be_cached do
  match_for_should do |actual|
    actual.assert_selector('.detail.time', text: 'cached')
  end

  match_for_should_not do |actual|
    actual.assert_no_selector('.detail.time', text: 'cached')
  end
end

World(RSpec::Matchers)
