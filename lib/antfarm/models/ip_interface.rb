################################################################################
#                                                                              #
# Copyright (2008-2012) Sandia Corporation. Under the terms of Contract        #
# DE-AC04-94AL85000 with Sandia Corporation, the U.S. Government retains       #
# certain rights in this software.                                             #
#                                                                              #
# Permission is hereby granted, free of charge, to any person obtaining a copy #
# of this software and associated documentation files (the "Software"), to     #
# deal in the Software without restriction, including without limitation the   #
# rights to use, copy, modify, merge, publish, distribute, distribute with     #
# modifications, sublicense, and/or sell copies of the Software, and to permit #
# persons to whom the Software is furnished to do so, subject to the following #
# conditions:                                                                  #
#                                                                              #
# The above copyright notice and this permission notice shall be included in   #
# all copies or substantial portions of the Software.                          #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  #
# ABOVE COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, #
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR #
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE          #
# SOFTWARE.                                                                    #
#                                                                              #
# Except as contained in this notice, the name(s) of the above copyright       #
# holders shall not be used in advertising or otherwise to promote the sale,   #
# use or other dealings in this Software without prior written authorization.  #
#                                                                              #
################################################################################

module Antfarm
  module Models
    class IpInterface < ActiveRecord::Base
      attr_accessor :ip_addr

      belongs_to :layer3_interface, :inverse_of => :ip_interface

      after_create :create_ip_network
      after_create :associate_layer3_network
      after_create :publish_info

      validates :address,          :presence => true
      validates :layer3_interface, :presence => true

      # Overriding the address setter in order to create an instance variable for an
      # Antfarm::IPAddrExt object ip_addr. This way the rest of the methods in this
      # class can confidently access the ip address for this interface. IPAddr also
      # validates the address.
      #
      # the method address= is called by the constructor of this class.
#     def address=(ip_addr) #:nodoc:
#       @ip_addr = Antfarm::IPAddrExt.new(ip_addr)
#       super(@ip_addr.to_s)
#     end

      # Validate data for requirements before saving interface to the database.
      #
      # Was using validate_on_create, but decided that restraints should occur
      # on anything saved to the database at any time, including a create and an update.
      validates_each :address do |record, attr, value|
        begin
          record.ip_addr = Antfarm::IPAddrExt.new(value)
          record.address = record.ip_addr.to_s

          # Don't save the interface if it's a loopback address.
          if record.ip_addr.loopback_address?
            record.errors.add(:address, 'loopback address not allowed')
          end

          # If the address is public and it already exists in the database, don't create
          # a new one but still create a new IP Network just in case the data given for
          # this address includes more detailed information about its network.
          unless record.ip_addr.private_address?
            interface = IpInterface.find_by_address(record.address)
            if interface
              record.create_ip_network
              message = "#{record.address} already exists, but a new IP Network was created"
              record.errors.add(:address, message)
              Antfarm.output message
            end
          end
        rescue ArgumentError
          record.errors.add(:address, "Invalid IP address: #{value}")
        end
      end

      def create_ip_network
        # Check to see if a network exists that contains this address.
        # If not, create a small one that does.
        unless Layer3Network.network_containing(self.address)
          self.ip_addr.netmask = self.ip_addr.netmask << 3 if self.ip_addr == self.ip_addr.network
          IpNetwork.create!(:address => self.ip_addr.to_cidr_string)
        end
      end

      def associate_layer3_network
        if layer3_network = Layer3Network.network_containing(self.address)
          self.layer3_interface.update_attribute :layer3_network, layer3_network
        end
      end

      def publish_info
          node = self.layer3_interface.layer2_interface.node
          net  = self.layer3_interface.layer3_network.ip_network
          data = { :link => { :source => "node:#{node.id}", :target => "net:#{net.id}", :value => 1 } }
          Antfarm.output 'create', JSON.generate(data)
      end
    end
  end
end
