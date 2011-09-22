require 'database_cleaner/active_road/base'
require 'database_cleaner/active_record/truncation'

module DatabaseCleaner
  module ActiveRoad
    class Truncation < DatabaseCleaner::ActiveRecord::Truncation
      include DatabaseCleaner::ActiveRoad::Base
    end
  end
end
