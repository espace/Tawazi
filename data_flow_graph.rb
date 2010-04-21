require 'operator.rb'
module Tawazi
 
  class DataFlowGraph < Tawazi::Operator
    attr_accessor :operators #an hash of operators (name, operator)
    def initialize(name,input_flows,operators)
      super(name,input_flows,nil)
      @operators = operators
    end
    
    def run
      @operators.each do |n,operator|
        if operator.instance_of?(DataFlowGraph) #The case of using a sub-graph
          operator.operators.each do |sub_n,sub_operator|
            sub_operator.run
          end
        else
          operator.run  
        end
      end
      join #join all running threads
    end#run
    
    def join
      @operators.each do |n,operator|
        if operator.instance_of?(DataFlowGraph) #The case of using a sub-graph
          operator.operators.each do |sub_n,sub_operator|
            sub_operator.join
          end
        else
          operator.join
        end
      end
    end#join
    
  end#DataFlowGraph
end#Tawazi