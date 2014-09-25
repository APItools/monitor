require 'headless'

headless = Headless.new

AfterConfiguration do
  headless.start
end

at_exit do
  headless.destroy
end
