# Filter Physical Road by : 
#  - forbidden_tags
class ActiveRoad::PhysicalRoadFilter
  attr_accessor :relation, :constraints

  def initialize(constraints = {}, relation = ActiveRoad::PhysicalRoad.scoped ) 
    @relation, @constraints = relation, constraints
  end

  # Must define an sql request with forbidden tags
  def sql_request
    sql_request = ""
    constraints.each do |key, value|
      if !( (constraints.keys.first.present? && constraints.keys.first == key) )  
        sql_request += " AND "
      end
  
      sql_request += "(tags -> '#{new_key}')::int > :#{key}"
      
      # if key.to_s.include? "min_" 
      #   new_key = key.to_s.gsub("min_", "")
      #   sql_request += "(tags -> '#{new_key}')::int > :#{key}"
      # elsif key.to_s.include? "max_"
      #   new_key = key.to_s.gsub("max_", "")
      #   sql_request += "(tags -> '#{new_key}')::int < :#{key}"
      # else
      #   sql_request += "tags -> '#{key}' != :#{key}" 
      # end
    end
    sql_request
  end

  def filter
    if constraints.present?      
      @relation = @relation.where(constraints)
    else
      @relation
    end
  end

end
