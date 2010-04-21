require 'input_port'
module Tawazi
   class Operator
    attr_accessor :name
    attr_accessor :input_ports #typically a hash table input ports. each Port is connected with a flow
    attr_accessor :output_flows #typically a hash table of flow objects
    attr_accessor :proc #A Proc defined with the block of code describes its processing algorithm
    attr_accessor :thread #A thread to run the proc
    def initialize(name,input_flows,proc)
      @name = name
      #print "#{name} created \n"
      @input_ports = {}
      input_flows.each do |flow_name,input_flow| 
          @input_ports["#{@name}_#{flow_name}"] = InputPort.new("#{@name}_#{flow_name}",input_flow) #use operator name as a name-space to avoid name conflicts across operators. 
      end
      @output_flows = {}
      @proc = proc
      
    end
    def run
      @thread = Thread.new {proc.call}
    end
    def get_input_port(flow_name)
      return @input_ports["#{@name}_#{flow_name}"]
    end
    def join
      @thread.join
    end
  end
end