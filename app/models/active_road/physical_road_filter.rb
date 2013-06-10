# Filter Physical Road by : 
#  - forbidden_tags
#  - kind
class ActiveRoad::PhysicalRoadFilter
  attr_accessor :relation, :forbidden_tags

  def initialize(forbidden_tags = {}, relation = ActiveRoad::PhysicalRoad.scoped ) 
    @relation, @forbidden_tags = relation, forbidden_tags
  end

  # Must define an sql request with forbidden tags
  def sql_request
    sql_request = ""
    forbidden_tags.each do |key, value|
      if !( (forbidden_tags.keys.first.present? && forbidden_tags.keys.first == key) )  
        sql_request += " AND "
      end
  
      if key.to_s.include? "min_" 
        new_key = key.to_s.gsub("min_", "")
        sql_request += "(tags -> '#{new_key}')::int > :#{key}"
      elsif key.to_s.include? "max_"
        new_key = key.to_s.gsub("max_", "")
        sql_request += "(tags -> '#{new_key}')::int < :#{key}"
      else
        sql_request += "tags -> '#{key}' != :#{key}" 
      end
    end
    sql_request
  end

  def sql_arguments
    forbidden_tags
  end

  def filter
    sql_arguments.present? ? @relation.where(sql_request, sql_arguments) : @relation
  end

  def find_each(&block)
    # @relation.where()
  end

end
