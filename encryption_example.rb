require "digest"
require 'data_flow_graph.rb'
require 'openssl'
require 'digest/sha1'

module Tawazi
  #This file is an example in using DataFlowGraph in doing a flow of encryption functions to encrypt, sign
  #and envelope a message according to the graph shown in the image: envelope.jpg
 $debug = false
 class Message < Tawazi::Operator
    def initialize(name,num)
      super(name,{},nil)
      @output_flows['m'] = Flow.new
      @proc = Proc.new do 
        num.times do |i|
          @output_flows['m'].write("#{i}")
          print "message number: #{i}\n" if $debug
        end
          @output_flows['m'].write_eof #end of flow
       end
    end
  end  
  class PRG < Tawazi::Operator
    def initialize(name,num)
      super(name,{},nil)
      @output_flows['random'] = Flow.new
      @proc = Proc.new do 
        num.times do |i|
          @output_flows['random'].write(Digest::SHA1.hexdigest(Time.now.to_s.split(//).sort_by{rand}.join))
          print "key number: #{i}\n" if $debug
        end
          @output_flows['random'].write_eof #end of flow
       end
    end
  end

  class AES < Tawazi::Operator
    def initialize(name,m_flow,k_flow)
      super(name,{'m' => m_flow, 'k' => k_flow},nil)
      @output_flows['c'] = Flow.new
      @proc = Proc.new do
        i=0
        m_eof ,k_eof = false, false
        aes = OpenSSL::Cipher::Cipher.new("aes-128-cbc")
        iv =  aes.random_iv #use one random vector for all encryptions to simplify the example
        while !m_eof && !k_eof
          m_eof, m =  get_input_port('m').next_token   
          k_eof, k =  get_input_port('k').next_token
          if !m_eof && !k_eof
            
            aes.encrypt
            aes.key = Digest::SHA1.hexdigest(k)
            aes.iv = iv
            c = aes.update(m)
            c << aes.final
            @output_flows['c'].write(c)
            print "AES number: #{i}\n" if $debug
            i += 1
          end#if !eof1 && !eof2
        end#while
        @output_flows['c'].write_eof
      end#proc
    end#initialize
  end#class

  class SHA < Tawazi::Operator
    def initialize(name,m_flow)
      super(name,{'m' => m_flow},nil)
      @output_flows['d'] = Flow.new
      @proc = Proc.new do
        i=0
        m_eof = false
        while !m_eof
          m_eof, m =  get_input_port('m').next_token   
          if !m_eof 
            d = Digest::SHA1.hexdigest(m)
            @output_flows['d'].write(d)
            print "sha number: #{i}\n" if $debug
            i += 1
          end#if !eof1 && !eof2
        end#while
        @output_flows['d'].write_eof
      end#proc
    end#initialize
  end#class

 class RSA < Tawazi::Operator
    def initialize(name,m_flow,is_prvt) #we will use a fixed key for Pu and Pr for simplicity.
      super(name,{'m' => m_flow},nil)
      @output_flows['c'] = Flow.new
      @proc = Proc.new do
        i=0
        m_eof = false
        key = OpenSSL::PKey::RSA.generate( 1024 )
        while !m_eof
          m_eof, m =  get_input_port('m').next_token   
          if !m_eof
            c = key.private_encrypt(m) if is_prvt
            c = key.public_encrypt(m) if !is_prvt
            
            @output_flows['c'].write(c)
            print"#{@name} number: #{i}\n" if $debug
            i += 1
          end#if !eof1 && !eof2
        end#while
        @output_flows['c'].write_eof
      end#proc
    end#initialize
  end#class

  class Env < Tawazi::Operator
    def initialize(name,c_flow,s_flow,k_dash_flow)
      super(name,{'c' => c_flow, 's' => s_flow, 'k_dash' => k_dash_flow},nil)
      @output_flows['env'] = Flow.new
      @proc = Proc.new do
        c_eof ,s_eof, k_dash_eof = false, false, false
        i=0
        while !c_eof && !s_eof && !k_dash_eof
          c_eof, c =  get_input_port('c').next_token   
          s_eof, s =  get_input_port('s').next_token
          k_dash_eof, k_dash =  get_input_port('k_dash').next_token
          if !c_eof && !s_eof && !k_dash_eof
            env = {'c' =>c,'s' => s, 'k_dash' =>k_dash}
            @output_flows['env'].write(env)
            print "envelop number: #{i}\n" if $debug
            i += 1
          end#if !eof1 && !eof2
        end#while
        @output_flows['env'].write_eof
      end#proc
    end#initialize
  end#class
  
  class Spliter < Tawazi::Operator
    def initialize(name,input_flow,number)#input_flow will be splitted into "number" of output flows with names 1, 2,...,10,...,100
      super(name,{'input_flow' => input_flow},nil)
      number.times {|i| @output_flows["#{i+1}"] = Flow.new}
      @proc = Proc.new do
        eof = false
        while !eof
          eof, token =  get_input_port('input_flow').next_token   
          if !eof
            number.times {|i| @output_flows["#{i+1}"].write(token)}
          end#if !eof
        end#while
        number.times {|i| @output_flows["#{i+1}"].write_eof}
      end#proc
    end#initialize
    
  end
  $num = 100000
  def self.envelope
    puts 'Start envelope'
    start_time = Time.new
    message = Message.new('message',$num)
    msg_spliter = Spliter.new('msg_spliter',message.output_flows['m'],2)
    prg = PRG.new('prg',$num)
    prg_spliter = Spliter.new('prg_spliter',prg.output_flows['random'],2)
    rsa_enc = RSA.new('rsa_enc',prg_spliter.output_flows['1'],false)
    aes = AES.new('aes',msg_spliter.output_flows['1'],prg_spliter.output_flows['2'])
    sha = SHA.new('sha',msg_spliter.output_flows['2'])
    rsa_sign = RSA.new('rsa_sign',sha.output_flows['d'],true)
    env = Env.new('env',aes.output_flows['c'],rsa_sign.output_flows['c'],rsa_enc.output_flows['c'])
    g = DataFlowGraph.new('envelope',{},{'message'=>message, 'msg_spliter' => msg_spliter, 'prg'=>prg,'prg_spliter' => prg_spliter , 'rsa_enc' => rsa_enc, 'aes' =>aes, 'sha' => sha, 'rsa_sign' => rsa_sign, 'env' => env})
    g.run
    end_time = Time.new
    puts "Time: #{end_time.to_f - start_time.to_f}"
    puts 'Done envelope'
  end
  
  def self.synch_envelope
    puts 'Start synch_envelope'
    start_time = Time.new
    message = Message.new('message',$num)
    prg = PRG.new('prg',$num)
    rsa_enc = RSA.new('rsa_enc',prg.output_flows['random'],false)
    aes = AES.new('aes',message.output_flows['m'],prg.output_flows['random'])
    sha = SHA.new('sha',message.output_flows['m'])
    rsa_sign = RSA.new('rsa_sign',sha.output_flows['d'],true)
    env = Env.new('env',aes.output_flows['c'],rsa_sign.output_flows['c'],rsa_enc.output_flows['c'])
    g = DataFlowGraph.new('envelope',{},{'message'=>message, 'prg'=>prg, 'rsa_enc' => rsa_enc, 'aes' =>aes, 'sha' => sha, 'rsa_sign' => rsa_sign, 'env' => env})
    g.run
    end_time = Time.new
    puts "Time: #{end_time.to_f - start_time.to_f}"
    puts 'Done synch_envelope'
  end

  
  
  def self.sequential_envelope
    puts 'Start sequential_envelope'
    start_time = Time.new
    #messages
    message = []
    $num.times do |i|
      message << "#{i}"
      print "message number: #{i}\n" if $debug
    end
    
    #prg
    prg = []
    $num.times do |i|
      prg << Digest::SHA1.hexdigest(Time.now.to_s.split(//).sort_by{rand}.join)
      print "key number: #{i}\n" if $debug
    end
    
    #rsa_enc
    k_dash = []
    pub = OpenSSL::PKey::RSA.generate( 1024 )
    $num.times do |i|
      m = prg[i]
      k_dash << pub.public_encrypt(m)
      print"rsa_enc number: #{i}\n" if $debug
    end#times

    #aes
    c = []
    aes = OpenSSL::Cipher::Cipher.new("aes-128-cbc")
    iv =  aes.random_iv #use one random vector for all encryptions to simplify the example
    $num.times do |i|
      m =  message[i]   
      k =  prg[i]
      aes.encrypt
      aes.key = Digest::SHA1.hexdigest(k)
      aes.iv = iv
      e = aes.update(m)
      e << aes.final
      c << e
      print "AES number: #{i}\n" if $debug
    end#times
    
    #sha
    sha = []
    $num.times do |i|
      m =  message[i]   
      d = Digest::SHA1.hexdigest(m)
      sha << d
      print "sha number: #{i}\n" if $debug
    end#while    

    #rsa_sign
    s = []
    prv = OpenSSL::PKey::RSA.generate( 1024 )
    $num.times do |i|
      m = sha[i]
      s << prv.private_encrypt(m)
      print"rsa_enc number: #{i}\n" if $debug
    end#times

    #env
    env =[]
    $num.times do |i|
      env = {'c' =>c[i],'s' => s[i], 'k_dash' =>k_dash[i]}
      print "envelop number: #{i}\n" if $debug
    end
    
    end_time = Time.new
    puts "Time: #{end_time.to_f - start_time.to_f}"
    puts 'Done envelope_sequential'
  end

  
  envelope
  sequential_envelope
  synch_envelope
end