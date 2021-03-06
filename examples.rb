require 'data_flow_graph.rb'
#This file shows use different ways to compose your application data flow graph. It starts with a quick
#example in which you do not need to create any special operator an you put all of your logic into
#one function only. Then, in Example 2 you will see how to define your operators via Operator class
#inheritance. Example 3 shows how you can reuse a previously defined graph as an operator in your graph.  
module Tawazi
  #Example 1:Single function graph composition
  #In this example we will compose a data flow graph using only one function calling. No inheritance is required
  #This example describes a graph of three nodes. One of them is a producer for the numbers from 1 to 10000.
  #The other two nodes are identical operators (workers). each of them consume the data flow generated by the producer and print the numbers it consumes.
  def self.single_function_graph_composition_example
    puts 'single_function_graph_composition_example Started'
    #define flows. Here we have one flow only. It will fan-out to feed both of the consumers. 
    numbers_flow = Flow.new
    #producer
    #name: P
    #input flows: none
    #function: generate an output flow called numbers_flow contains the numbers 1 to 10000
    producer = Operator.new('P',{},Proc.new do 
          producer.output_flows['numbers_flow'] = numbers_flow
          1000.times do |i| 
            numbers_flow.write(i)
            print "P: #{i}\n"
          end
          numbers_flow.write_eof #end of flow
       end)
    #consumer1
    #name: C1
    #input flows: only one flow: The flow generated by the producer
    #function: consume the tokens of the flow and print it
    consumer1 = Operator.new('C1',{'numbers_flow' => numbers_flow}, Proc.new do
         eof = false      
         while !eof
           eof, token =  consumer1.get_input_port('numbers_flow').next_token  
           print "C1: #{token}\n" if !eof
         end
     end)
     
     #consumer2
     #name: C2
     #input flows: only one flow: The flow generated by the producer
     #function: consume the tokens of the flow and print it
     consumer2 = Operator.new('C2',{'numbers_flow' => numbers_flow}, Proc.new do
         eof = false      
         while !eof
           eof, token =  consumer2.get_input_port('numbers_flow').next_token  
           print "C2: #{token}\n" if !eof
         end
     end)
     #graph
     #name: test
     #input flows: none
     #nodes: producer, consumer1, consumer2     
     g = DataFlowGraph.new('test',{},{'P'=>producer,'C1'=>consumer1,'C2'=>consumer2}) #compose
     g.run #parallel execution
     puts 'single_function_graph_composition_example Finished'
  end
 
 
  #Example 2:Defining new operators
  class Producer < Tawazi::Operator
      def initialize(name)
        super(name,{},nil)
        @output_flows['numbers_flow'] = Flow.new
        @proc = Proc.new do 
            1000.times do |i| 
              @output_flows['numbers_flow'].write(i)
              print "P: #{i}\n"
            end
            @output_flows['numbers_flow'].write_eof #end of flow
         end
      end
  end
 
  class Consumer < Tawazi::Operator
      def initialize(name,numbers_flow)
        super(name,{'numbers_flow' => numbers_flow},nil)
        @proc = Proc.new do
           eof = false      
           while !eof
             eof, token =  get_input_port('numbers_flow').next_token  
             print "#{@name}: #{token}\n" if !eof
           end
       end
    end
  end
  
  class OddFilter < Tawazi::Operator #Takes a flow of numbers and generates a flow of odd numbers only
    def initialize(name,numbers_flow)
      super(name,{'numbers_flow' => numbers_flow},nil)
      @output_flows['odd_numbers_flow'] = Flow.new
      @proc = Proc.new do
         eof = false      
         while !eof
           eof, token =  get_input_port('numbers_flow').next_token  
           @output_flows['odd_numbers_flow'].write(token) if !eof && token % 2 != 0
         end
         @output_flows['odd_numbers_flow'].write_eof
       end
    end
  end

 class OddNumbersGraph < Tawazi::DataFlowGraph
    def initialize(name)
      super(name,{},nil)
      producer = Producer.new('P')#create
      odd_filter = OddFilter.new('odd_filter',producer.output_flows['numbers_flow'])#create and wire
      @operators = {'P' =>producer, 'odd_filter' =>odd_filter}
      @output_flows = {}
      @output_flows['odd_numbers_flow'] = odd_filter.output_flows['odd_numbers_flow']#wire to the external world
    end
  end


 
  def self.defining_new_operators_example
    puts 'defining_new_operators_example Started'
    producer = Producer.new('P') #create
    consumer1 = Consumer.new('C1',producer.output_flows['numbers_flow'])#create and wire
    consumer2 = Consumer.new('C2',producer.output_flows['numbers_flow'])#create and wire
    g = DataFlowGraph.new('test',{},{'P'=>producer,'C1'=>consumer1,'C2'=>consumer2}) #compose
    g.run #parallel execution
    puts 'defining_new_operators_example Finished'
  end
 
  #Example 3: Reusing a sub graph 
  def self.reusing_graph_example
   puts 'reusing_graph_example Started'
   odd_numbers_graph = OddNumbersGraph.new('odd_numbers_graph') #data flow graph is an operator by definition
   consumer1 = Consumer.new('C1',odd_numbers_graph.output_flows['odd_numbers_flow'])#create and wire
   consumer2 = Consumer.new('C2',odd_numbers_graph.output_flows['odd_numbers_flow'])#create and wire
   g = DataFlowGraph.new('test',{},{'odd_numbers_graph'=>odd_numbers_graph,'C1'=>consumer1,'C2'=>consumer2}) #compose using the sub-graph
   g.run #parallel execution
   puts 'reusing_graph_example Finished'
 end
 
 #run examples
 
 #run example 1
 single_function_graph_composition_example
 #run example 2
 defining_new_operators_example
 #run example 3
 reusing_graph_example
end
 