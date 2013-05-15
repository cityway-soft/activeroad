class ActiveRoad::PhysicalRoadFilter
  attr_accessor :relation, :tags, :kind

  def initialize(tags = {}, kind = "road", relation = ActiveRoad::PhysicalRoad.scoped )    
    @relation, @tags, @kind = relation, tags, kind
  end

  def sql_request
    sql_request = ""
    tags.each do |key, value|
      if !( (tags.keys.first.present? && tags.keys.first == key) )  
        sql_request += " AND "
      end
  
      if key.to_s.include? "min_" 
        new_key = key.to_s.gsub("min_", "")
        sql_request += "(tags -> '#{new_key}')::int > :#{key}"
      elsif key.to_s.include? "max_"
        new_key = key.to_s.gsub("max_", "")
        sql_request += "(tags -> '#{new_key}')::int < :#{key}"
      else
        sql_request += "tags -> '#{key}' = :#{key}" 
      end
    end
    
    tags.present? ? sql_request += " AND kind = :kind" : sql_request += "kind = :kind"
  end

  def sql_arguments
    tags.merge({ :kind => kind }) 
  end

  def filter
    @relation.where(sql_request, sql_arguments)
  end

  def find_each(&block)
    # @relation.where()
  end

end
