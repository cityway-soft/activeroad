module ActiveRoad
  class RequestConditionnalCostLinker
    attr_accessor :unauthorized_constraints, :authorized_constraints, :constraints

    def initialize(constraints = [], external_constraints = {})
      @constraints = constraints
    end 

    def unauthorized_constraints
      @unauthorized_constraints ||= [].tap do |unauthorized_constraints|
        constraints.each do |constraint|
          if constraint.start_with?("~")
            unauthorized_constraints << constraint.gsub("~", "")
          end  
        end
      end
    end

    def authorized_constraints 
      @authorized_constraints ||= [].tap do |authorized_constraints|
        constraints.each do |constraint|
          if !constraint.start_with?("~")
            authorized_constraints << constraint
          end  
        end
      end
    end

    def authorized_constraints_intersection_with?(tags)
      (authorized_constraints & tags == false || authorized_constraints & tags == []) ? false : true
    end

    def unauthorized_constraints_intersection_with?(tags)
      (unauthorized_constraints & tags == false || unauthorized_constraints & tags == []) ? false : true 
    end

    def linked?(conditionnal_costs_tags)
      authorized_constraints_intersection_with?(conditionnal_costs_tags) || unauthorized_constraints_intersection_with?(conditionnal_costs_tags)
    end

    def conditionnal_costs_linked(conditionnal_costs)
      conditionnal_costs.find_all_by_tags(authorized_constraints)
    end

    def conditionnal_costs_sum(conditionnal_costs)
      conditionnal_costs_tags = conditionnal_costs.collect(&:tags)  
      if linked?(conditionnal_costs_tags)
        if unauthorized_constraints && unauthorized_constraints_intersection_with?(conditionnal_costs_tags)
          return Float::INFINITY
        else
          return conditionnal_costs_linked(conditionnal_costs).collect(&:cost).sum 
        end
      else
        0
      end
    end
    
  end
end
