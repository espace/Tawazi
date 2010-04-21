require 'flow.rb'
module Tawazi
  class InputPort
    attr_accessor :name
    attr_accessor :flow #One or more input ports can share the same flow. This is the case of fan-out when you draw the graph diagram. 
    attr_accessor :index
    def initialize(name,flow)
      @name = name
      @flow = flow
      flow.add_reader_port(self)
      @index = 0
    end
    def next_token
      #This method:
      #1-advance the flow pointer
      #2-return the token
      #3-test EOF
      if flow == nil
        return ture,EOF.new
      end
      token = @flow.read(name)
      return token.instance_of?(EOF),token
    end
 
    def detach
      @flow.remove_reader_port(name)
      @flow = nil
    end
  end
end