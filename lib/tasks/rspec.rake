require 'rspec/core/rake_task'

namespace :activeroad do
  RSpec::Core::RakeTask.new(:spec)

  RSpec::Core::RakeTask.new(:rcov) do |t|
    t.rcov = true
    t.rcov_opts = %w{--exclude osx\/objc,gems\/,spec\/,lib\/database_cleaner\/}
  end
end
