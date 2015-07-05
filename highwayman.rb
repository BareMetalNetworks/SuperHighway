#!/usr/bin/env ruby
require 'json'
require 'optparse'
require 'readline'
require 'highline'
require 'net/ssh'
require 'fuzzy_match'
require 'redis'
$PROGRAM_NAME = 'IMS.rb'
$VERSION = '0.1.0'
###########################################################################################
# Author: SJK, Senior Developer, BareMetalNetworks.com                                    #
# First week of July 2015                                                                 #
##### Future Features #####################################################################
## Populate hosts hostname by calling each ip and running hostname during the setup       #
## Have both batch and single host command issue                                          #
## Write a parser/lexxer for builtins                                                     #
## History support -- redis                                                               #
## Refactor Node into Node                                                                #
## Dispatch table - builtin commands IMS> batch <command>  IMS> host :staged0 <command>   #
## Buildout options table                                                                 #
## Create another class to Manage those nodes?                                            #
## Output to a file or stuff in a database options -- redis                               #
## Batch command execution and cluster management REPL and plain vanilla CLI toolkit      #
## Redis backed store of hostname/node info plus node statistics & command issue returns  #
## Also redis backed store for fuzzymatch future.                                         #
###########################################################################################

## History match/Command completion
## Fuzzymatch.new(['foo', 'bar', 'baz']).find("far")



## Needs command parsing
## Stack0 is redis only server on 10.0.1.17
# On stack0 DB0 is for sysop's system events, DB1 is for IMS, DB2,3 reserved but unallocated,
# DB4 is for testing/junk


options = {}
opt_parser = OptionParser.new do |opts|
  exec_name = File.basename($PROGRAM_NAME)
  opts.banner = "###### Highway IMS ######## \n # BareMetal's Infrastructure Management Console\n
  # GNU Readline supported Ctrl-* and Alt-* emacs keybindings available\n
  Usage: #{exec_name} <options> \n""   "

  options[:version] = false
  opts.on('-v', '--verbose', 'Wordy output') { options[:verbose] = true}
  options[:logfile] = nil
  opts.on('-l', '--logfile FILE', 'Write STDOUT to a file') { |f| options[:logfile] = f }

  options[:redishost] = nil
  opts.on('-h', '--host REDIS-HOST', 'Redis database host, required for command completion, history, and pushing
events out to an alt interface (Like a web UI or a remote syslog srv). Defaults to localhost') { |h|
    options[:redishost] = h if  }

  options[:redisport] = nil
  opts.on('-p', '--port REDIS-PORT', 'Redis database host port') { |p| options[:redisport] = p }
  options[:redistable] = nil
  opts.on('-t', '--redis-table REDIS-DATABASE-TABLE', 'Redis database table number, e.g. 1 or 3') { |d|
    options[:redistable] = d }




end ; opt_parser.parse!

def setup_redis
  redis = Redis.new({:host => options[:redishost], :port => options[:redisport]})
  redis.select(options[:redistable])
  redis
end
redi = setup_redis('10.0.1.17', '6379', 1)

redi.key(:node_ips)?

all_srv = Array.new
all_srv = %w{10.0.1.200 10.0.1.32 10.0.1.27 10.0.1.10 10.0.1.7 10.0.1.19 10.0.1.20 10.0.1.21 10.0.1.22 10.0.1.28}

srvs = {:datastore0 => '10.0.1.18', :datastore2 => '10.0.1.32', :app2 => '10.0.1.27', :app3 => '10.0.1.28', :app1 => "10
.0..23"}


hosts = ARGV.shift || '/etc/superhighway/hosts.json'
password = ARGV.shift || false
$XGUI = ARGV.shift || false
#running on xwindows system opt and non xwindows but forward to xwindows opt
# extended prompt yes||No
$EXTENDPROMPT = true

# if hosts && File.exists?(hosts)
#   main(hosts)
#
#   # TODO finish this
# #elsif #parser
#  # `git clone https://github.com/baremetalnetworks/clusterforge`
#
# else
#   STDERR.puts "Error: Couldn't find an infrastructure.hosts YAML file, creating one now in /tmp from /etc/hosts"
#   `touch /tmp/hosts.json`
#   p 'restart the REPL'
#   #exit 1
# end

$stack = Array.new

def lexxsexx(expr, opsTable)
  tokens = expr.split(" ")
  tokens.each do |tok|
    type = tok =~ /\A\w+\Z/ ? :tok : nil
    opsTable[type || tok][tok]
  end
end

  class Node
    attr_accessor :host, :user, :password, :running, :results

    def initialize(host, user, password)
      @host = host
      @user = user
      @password = password
      @results = Array.new
      @running = false
      #@key = key
    end
    def shexec(command)
      Net::SSH.start(@host, @user, :password => @password) do |ssh|
        ssh.open_channel do |channel|
          channel.exec command do |channel, success|
            raise "Could not execute #{command}" unless success
            channel.on_data do |channel, data|
              return data

            end
          end
        end
      end
    end
  end

$history = Array.new # for history cache



def main(srvs)
  command = nil
  cmd_count = 0
  conns = Array.new

  # Construct node objects, populate them with hash: keys are hostnames and value is array for results
  srvs.each {|srv| conns.push(Node.new(srv, 'vishnu', 'password' ))}
  ## store hostnames in redis with a 5min expiry
  conns.each {|conn| h = conn.shexec('hostname'); conn.running = true  }

  # Function issuers, threaded and non-threaded
  threadedcmd = lambda { |conn| Thread.new { conn.results.push(conn.shexec(command)) }}
  #threadedcmd = lambda { |conn| Thread.new { p "### Host #{conn.host} ###\n" + conn.shexec(command) }}
  issuecmd = lambda { |conn|  p "### Host #{conn.host} ###\n" + conn.shexec(command) }


  begin
    while command != ('exit' || 'quit')
      command = Readline.readline("#{Time.now}-#{cmd_count.to_s}-IMS> ")
      break if command.nil?
      cmd_count += 1
      $history.push command if $history.include?(command)
      `notify-send "Issuing command: [#{command}] to host(s) [#{host.keys}]"` if $XGUI
      begin
        conns.each {|conn| threadedcmd.call(conn) if conn.running}

      rescue => err
        pp "[Issuer] Error: #{err.inspect} #{err.backtrace}"
        next
      end
      p nodeRes
    end

  rescue => err
    pp "[Main] Error: #{err.inspect} #{err.backtrace} on #{File.}"
    retry
  end
end

main(all_srv)