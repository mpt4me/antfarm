module Antfarm
  module Pcap
    def self.registered(plugin)
      plugin.name = 'pcap'
      plugin.info = {
        :desc   => 'Parse PCAP data',
        :author => 'Bryan T. Richardson'
      }
      plugin.options = [{
        :name     => 'file',
        :desc     => 'File containing PCAP data',
        :type     => String,
        :required => true
      }]
    end

    def run(opts = Hash.new)
      check_options(opts)

      require 'packetfu'
      require 'packetfu/modbus'

      if File.readable?(opts[:file])
        PacketFu::PcapFile.read_packets(opts[:file]) do |pkt|
          if pkt.proto.include?('IP')
            smaddr = pkt.eth_saddr.upcase
            dmaddr = pkt.eth_daddr.upcase
            siaddr = pkt.ip_saddr
            diaddr = pkt.ip_daddr

            if s_ip_iface = Antfarm::Models::IpInterface.find_by_address(siaddr)
              l2iface = s_ip_iface.layer3_interface.layer2_interface

              if l2iface.ethernet_interface
                if l2iface.certainty_factor < Antfarm::CF_PROVEN_TRUE
                  l2iface.ethernet_interface.update_attribute :address, smaddr
                end
              else
                l2iface.create_ethernet_interface! :address => smaddr
              end
            else
              node    = Antfarm::Models::Node.create! :certainty_factor => 0.5, :device_type => 'PCAP'
              l2iface = node.layer2_interfaces.create! :certainty_factor => Antfarm::CF_PROVEN_TRUE,
                          :ethernet_interface_attributes => { :address => smaddr }

              l2iface.tags.create! :name => Antfarm::OuiParser.get_name(smaddr) || 'Unknown Vendor'

              l3iface = l2iface.layer3_interfaces.create! :certainty_factor => Antfarm::CF_PROVEN_TRUE,
                          :ip_interface_attributes => { :address => siaddr }
            end

            if pkt.proto.include?('Modbus')
              if pkt.tcp_src == 502
                l2iface.node.tags.create! :name => 'Modbus TCP Slave'
              elsif pkt.tcp_dst == 502
                l2iface.node.tags.create! :name => 'Modbus TCP Master'
              end
            end

            if d_ip_iface = Antfarm::Models::IpInterface.find_by_address(diaddr)
              l2iface = d_ip_iface.layer3_interface.layer2_interface

              if l2iface.ethernet_interface
                if l2iface.certainty_factor < Antfarm::CF_PROVEN_TRUE
                  l2iface.ethernet_interface.update_attribute :address, dmaddr
                end
              else
                l2iface.create_ethernet_interface! :address => dmaddr
              end
            else
              node    = Antfarm::Models::Node.create! :certainty_factor => 0.5, :device_type => 'PCAP'
              l2iface = node.layer2_interfaces.create! :certainty_factor => Antfarm::CF_PROVEN_TRUE,
                          :ethernet_interface_attributes => { :address => dmaddr }

              l2iface.tags.create! :name => Antfarm::OuiParser.get_name(dmaddr) || 'Unknown Vendor'

              l3iface = l2iface.layer3_interfaces.create! :certainty_factor => Antfarm::CF_PROVEN_TRUE,
                          :ip_interface_attributes => { :address => diaddr }
            end

            if pkt.proto.include?('Modbus')
              if pkt.tcp_src == 502
                l2iface.node.tags.create! :name => 'Modbus TCP Master'
              elsif pkt.tcp_dst == 502
                l2iface.node.tags.create! :name => 'Modbus TCP Slave'
              end
            end
          end
        end
      else
        raise "Infput file #{opts[:file]} doesn't exist."
      end
    end
  end
end

Antfarm.register(Antfarm::Pcap)
