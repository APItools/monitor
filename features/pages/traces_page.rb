require 'active_support/core_ext/module/delegation'

class TracesPage
  include Capybara::DSL

  class Trace
    delegate :assert_selector, :assert_no_selector, to: :@element

    def initialize(element)
      @element = element
    end
  end

  def has_traces?(count)
    assert_selector(traces, count: count)
  end

  def has_a_trace?
    assert_selector(traces)
  end

  def last_trace
    trace = first(traces)
    TracesPage::Trace.new(trace)
  end

  def load_more
    click_on('load-more')
    assert_no_selector('#search-loading', visible: true)
  end

  private

  def traces
    'ul[slug-list] li[slug-item].trace'
  end
end
