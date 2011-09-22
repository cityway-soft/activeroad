require 'database_cleaner/active_road/base'
require 'database_cleaner/active_record/transaction'

module DatabaseCleaner
  module ActiveRoad
    class Transaction < DatabaseCleaner::ActiveRecord::Transaction
      include DatabaseCleaner::ActiveRoad::Base
    end
  end
end
