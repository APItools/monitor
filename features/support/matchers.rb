require 'rspec/expectations'

RSpec::Matchers.define :be_cached do
  match do |actual|
    actual.assert_selector('.detail.time', text: 'cached')
  end

  match_when_negated do |actual|
    actual.assert_no_selector('.detail.time', text: 'cached')
  end
end

World(RSpec::Matchers)
