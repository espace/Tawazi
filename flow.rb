require 'monitor.rb'
require 'thread.rb'
require 'input_port.rb'
require 'eof.rb'

module Tawazi
  class Flow < Monitor
    
    def initialize
      super
      @ports = {}
      @queue = Queue.new
      #In the case of multiple input ports the flow uses @heads array to keep the tokens needed by the slow consumer ports.
      #It is shifted regularly to drop the old tokens that are not needed any more by any input port.
      #You can imagine the data structure as a blocking queue (@queue) with head extension (@heads)  
      @heads = [] 
      @eof = false
    end
    
    def add_reader_port(port)
      synchronize do
        @ports[port.name] = port
      end
    end
    
    def remove_reader_port(name)
      synchronize do
        @ports.delete(name)
      end
    end
    
    
    def write(token) # the write method uses enq which is thread-safe. It needs no explicit synch.
      @queue.enq(token)
    end
    
    def write_eof #You must use this function once for a flow to make sure your graph execution will terminate.
      @queue.enq(EOF.new)
    end

    def read(port_name)
     # This method is quite complex to handle reading by more than one input port.
     # Generally, when you need to fan-out an output flow of one operator you may do this via one of the following ways:
     # 1-Pass the output flow an an input to all depending operators. In this case the read method will
     # enter the synchronize block below. The pro is the ease of use. The con is the low performance in most of cases.
     # 2-You can use "splitter" operator takes one input flow and repeat it into "n" output flows. This gives you 
     # a significant performance improvement in the case of large number of cores. On the other hand your graph will be larger and less focus on your main logic. 
     
     if(@ports.length ==1) 
        return EOF.new if eof?
        token = @queue.deq
        @eof = true if token.instance_of?(EOF)
        return token
      end
      synchronize do
        index = @ports[port_name].index #each port is an observer. It keeps an index to the current element. Ports consume tokens in different speeds
        #print "#{port_name}, #{index}\n"  #For debuging purposes.
        if index < 0 #Then it is one of the slow ports
          token = @heads[index] # All the elements needed by the slow ports are kept in @heads with -ve index. -1 means the first element before the head of the @queue
          @ports[port_name].index = index + 1 # update index
          if min_index >= @ports[port_name].index
            @heads.shift #remove the first item. No one will need it later
          end
          return token
        else #The index is 0. It will not exceed 0
          return EOF.new if eof?
          token = @queue.deq
          @eof = true if token.instance_of?(EOF)
          if @ports.size != 1
            @ports.each do |n,port|
              port.index = port.index-1
            end
            @heads << token #keep it. One of the slow flows will need it later.
            @ports[port_name].index = 0 #return it to zero. It is updated in the previous loop
          end
          return token
        end
      end#synch
    end#read
 
    def min_index #The global minimum index between all ports
      min = 0
      @ports.each do |n,port|
        if port.index < min
          min = port.index
        end
      end
      return min
    end
    
    def eof?
      return @eof
    end
  end

  
end
