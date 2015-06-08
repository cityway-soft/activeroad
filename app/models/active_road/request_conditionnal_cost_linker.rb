module ActiveRoad
  class RequestConditionnalCostLinker
    attr_accessor :unauthorized_constraints, :authorized_constraints, :constraints

    def initialize(constraints = {})
      @constraints = constraints
    end 

    def unauthorized_constraints
      @unauthorized_constraints ||= {}.tap do |unauthorized_constraints|
        constraints.each do |key, values|
          values.split(",").each do |value|
            if value.start_with?("~")
              if unauthorized_constraints.has_key?(key)
                unauthorized_constraints[key] << value.gsub("~", "")
              else
                unauthorized_constraints[key] = [value.gsub("~", "")]
              end
            end
          end
        end
      end
    end

    def authorized_constraints 
      @authorized_constraints ||= {}.tap do |authorized_constraints|
        constraints.each do |key, values|
          values.split(",").each do |value|
            if !value.start_with?("~")
              if authorized_constraints.has_key?(key)
                authorized_constraints[key] << constraint
              else
                authorized_constraints[key] = [constraint]
              end
            end  
          end
        end
      end
    end    
    

    def unauthorized_constraints_intersection_with?(physical_road)
      unauthorized_constraints.each do |key, values|
        physical_road_key = key.to_sym
        if physical_road.respond_to?(physical_road_key) && physical_road.send(physical_road_key).present?
          return true if values.include?( physical_road.send(physical_road_key) ) 
        end
      end
      return false
    end  
    
  end
end
