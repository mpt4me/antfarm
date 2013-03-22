require 'haml'
require 'sinatra/base'

module Antfarm
  module Web
    class Server < Sinatra::Base
      get '/graph' do
        haml :graph
      end

      get '/stream', :provides => 'text/event-stream' do
        stream :keep_open do |out|
          require 'json'

          nets  = Antfarm::Models::Layer3Network.all
          hosts = Array.new
          net   = nil

          nodes        = Array.new
          net_indexes  = Hash.new
          node_indexes = Hash.new

          EM::PeriodicTimer.new(0.25) do
            data = Hash.new

            if hosts.empty?
              net = nets.pop
              net_indexes[net.id] = nodes.length

              data[:node] = { :name => net.id, :group => 'LAN', :label => net.ip_network.address }
              nodes << net
              hosts = net.layer3_interfaces
            else
              node = hosts.pop.layer2_interface.node

              unless nodes.include?(node)
                node_indexes[node.id] = nodes.length
                data[:node] = { :name => node.id, :group => node.device_type, :label => node.name }
                nodes << node
              end

              data[:link] = { :source => node_indexes[node.id], :target => net_indexes[net.id], :value => 1 }
            end

            out << "data: #{JSON.generate(data)}\n\n"
          end
        end
      end
    end
  end
end
