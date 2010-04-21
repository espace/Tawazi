require 'data_flow_graph.rb'
module Tawazi
  #This rb file includes an example of  reading two sorted lists from two input files an merg them 
  #into one sorted list then write it to an output file. It was indended to be used in measuring the performance gain by using DataFlowGraph.
  #Actually, in this example the performance of the DataFlowGraph is worse than the sequential code.
  #This is mainly due to I/O. This example is an intensive I/O example. In other words the I/O operations
  #are much more than processing operations. To discover the power of DataFlowGraph please run the 
  #encryption_example.rb file
  
  class ReadTextFile < Tawazi::Operator
    def initialize(name,input_file_name)
      super(name,{},nil)
      @output_flows['lines_flow'] = Flow.new
      @proc = Proc.new do 
          File.open(input_file_name) do |file|
            while line = file.gets
              @output_flows['lines_flow'].write(line)
              #print "read\n"
            end
          end
          @output_flows['lines_flow'].write_eof #end of flow
       end
    end
  end
  

  class MergeSortedLists < Tawazi::Operator
    def initialize(name,input_lines1,input_lines2)
      super(name,{'input_lines1' => input_lines1, 'input_lines2' => input_lines2},nil)
      @output_flows['output_lines'] = Flow.new
      @proc = Proc.new do
        eof2 ,eof1 = false, false
        line1,line2=nil,nil
        advance1,advance2 = true,true
        while !eof1 || !eof2
          eof1, line1 =  get_input_port('input_lines1').next_token if  advance1  
          eof2, line2 =  get_input_port('input_lines2').next_token if  advance2
          line1 = line1.strip if !eof1
          line2 = line2.strip if !eof2
          #print "#{line1} , #{line2}\n"
          if !eof1 && !eof2
            if line1 <= line2
              @output_flows['output_lines'].write(line1)
              advance1 = true
              advance2 = false
            else
              @output_flows['output_lines'].write(line2)
              advance1 = false
              advance2 = true
            end
          elsif !eof1 
              @output_flows['output_lines'].write(line1)
              advance1 = true
              advance2 = false
          elsif !eof2
              @output_flows['output_lines'].write(line2)
              advance1 = false
              advance2 = true
          end#if !eof1 && !eof2
        end#while
        @output_flows['output_lines'].write_eof
      end#proc
    end#initialize
  end#class
  
  class WriteTextFile < Tawazi::Operator
    def initialize(name,lines_flow,output_file_name)
      super(name,{'lines_flow' => lines_flow},nil)
      @proc = Proc.new do 
        @file = File.new(output_file_name, "w")
        eof = false      
        while !eof
          eof, token =  get_input_port('lines_flow').next_token  
          @file.print "#{token}\n" if !eof
          #print "write\n" if !eof
        end
        @file.close
      end
    end
  end
  
  def self.generate_inputs(file_name,size,filter)
    puts "Start #{file_name}"
    mod2 = 1 if filter == 'odd'
    mod2 = 0 if filter == 'even'
    file = File.new(file_name, "w")
    size.times do |i|
      if (filter != 'all' && i % 2 == mod2) || filter == 'all'
        ("#{size}".length-"#{i}".length).times {file.print "0"}        
        file.print "#{i}\n"
      end
    end
    file.close
    puts "Done #{file_name}"
  end
  
  def self.sequential_merge_sorted_text_files
    puts 'Start sequential_merge_sorted_text_files'
    start_time = Time.new

    #read input1
    input1 = []
    File.open('input1.txt') do |file|
      while line = file.gets
       input1 << line
      end
    end

    #read input2
    input2 = []
    File.open('input2.txt') do |file|
      while line = file.gets
       input2 << line
      end
    end

    output_lines = []
    index1 ,index2 = 0, 0
    line1,line2=nil,nil
    advance1,advance2 = true,true
    
    while index1 <= input1.length || index2 <= input2.length
      if(advance1)
        line1 = input1[index1]
        index1 +=  1
      end

      if(advance2)
        line2 = input2[index2]
        index2 +=  1
      end

      
      line1 = line1.strip if index1 <= input1.length
      line2 = line2.strip if index2 <= input2.length
      #print "#{line1} , #{line2}\n"
      if index1 <= input1.length && index2 <= input2.length
        if line1 <= line2
          output_lines << line1
          advance1 = true
          advance2 = false
        else
          output_lines << line2
          advance1 = false
          advance2 = true
        end
      elsif index1 <= input1.length 
          output_lines << line1
          advance1 = true
          advance2 = false
      elsif  index2 <= input2.length
          output_lines << line2
          advance1 = false
          advance2 = true
      end#if !eof1 && !eof2
    end#while
    
    #write output
    @file = File.new('sequential_merge_sorted_text_files.txt', "w")
    output_lines.each { |token| @file.print "#{token}\n" }
    @file.close

    end_time = Time.new
    puts "#{end_time.to_f - start_time.to_f}"
    puts 'Done sequential_merge_sorted_text_files'
    
  end

  def self.merge_sorted_text_files_example
    puts 'Start merge_sorted_text_files_example'
    start_time = Time.new
    reader1 = ReadTextFile.new('reader1','input1.txt')
    reader2 = ReadTextFile.new('reader2','input2.txt')
    merg = MergeSortedLists.new('merge',reader1.output_flows['lines_flow'],reader2.output_flows['lines_flow'])
    writer = WriteTextFile.new('writer',merg.output_flows['output_lines'],'merge_sorted_text_files_example.txt')
    g = DataFlowGraph.new('merge_example',{},{'reader1'=>reader1,'reader2'=>reader2,'merg'=>merg,'writer'=>writer})
    g.run
    end_time = Time.new
    puts "#{end_time.to_f - start_time.to_f}"
    puts 'Done merge_sorted_text_files_example'
    
  end

  input_size = 10000
  
  def self.sequential
    #read into array then write this array 
    puts 'Start sequential'
    start_time = Time.new
   
    #read input1
    input1 = []
    File.open('input1.txt') do |file|
      while line = file.gets
       input1 << line
      end
    end
    
    #write output
    file = File.new('sequential.txt', "w")
    input1.each { |token| file.print "#{token}\n" }
    file.close
    
    end_time = Time.new
    puts "#{end_time.to_f - start_time.to_f}"
    puts 'Done sequential'
  end
  
  def self.independent_threads(input_size)
    puts 'Start independent_threads'
    #prepare input before starting the timer 
    input2 = []
    input_size.times do |i|
      z = ""
      ("#{input_size}".length-"#{i}".length).times {z += "0"}        
      input2 << "#{z}#{i}\n"
    end
    
    start_time = Time.new
   
    #read input1
    input1 = []
    ti = Thread.new do
      File.open('input1.txt') do |file|
        while line = file.gets
         input1 << line
       end
      end
    end
    
    #write output
    to = Thread.new do
      file = File.new('independent_threads.txt', "w")
      input2.each do |token| 
        file.print "#{token}\n"
      end
      file.close
    end
    
    ti.join
    to.join
    end_time = Time.new
    puts "#{end_time.to_f - start_time.to_f}"
    puts 'Done threads'

  end

  def self.dependent_threads

    puts 'Start dependent_threads'
    start_time = Time.new
   
    #read input1
    input1 = Queue.new
    ti = Thread.new do
      File.open('input1.txt') do |file|
        while line = file.gets
         input1.enq(line)
       end
       input1.enq(EOF.new)
      end
    end
    
    #write output
    to = Thread.new do
      file = File.new('dependent_threads.txt', "w")
      eof = false
      while !eof
        token = input1.deq 
        eof = token.instance_of?(EOF)
        file.print "#{token}\n" if !eof
      end
      file.close
    end
    
    ti.join
    to.join
    end_time = Time.new
    puts "#{end_time.to_f - start_time.to_f}"
    puts 'Done dependent_threads'

  end

  def self.tawazi
    puts 'Start tawazi'
    start_time = Time.new
    reader1 = ReadTextFile.new('reader1','input1.txt')
    writer = WriteTextFile.new('writer',reader1.output_flows['lines_flow'],'tawazi.txt')
    g = DataFlowGraph.new('tawazi',{},{'reader1'=>reader1,'writer'=>writer})
    g.run
    end_time = Time.new
    puts "#{end_time.to_f - start_time.to_f}"
    puts 'Done tawazi'
  end

  
 
    
  #generate input files
  generate_inputs('input1.txt',input_size,'all')
  generate_inputs('input2.txt',input_size,'all')
  
  #sequential
  sequential
  
  #independent threads
  independent_threads(input_size)
  
  #dependent threads
  dependent_threads

  #tawazi
  tawazi 
  
  
  merge_sorted_text_files_example
  sequential_merge_sorted_text_files
  
end