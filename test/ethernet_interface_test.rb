require 'helper'

class EthernetInterfaceTest < TestCase
  include Antfarm::Models

  test 'fails with no layer 2 interface' do
    assert_raises(ActiveRecord::RecordInvalid) do
      Fabricate :ethiface, :layer2_interface => nil
    end

    assert !Fabricate.build(:ethiface, :layer2_interface => nil).valid?
  end

  test 'fails with no address' do
    assert_raises(ActiveRecord::RecordInvalid) do
      Fabricate :ethiface, :address => nil
    end

    assert !Fabricate.build(:ethiface, :address => nil).valid?
  end

  test 'fails with invalid address' do
    assert_raises(ActiveRecord::RecordInvalid) do
      Fabricate :ethiface, :address => '00:00:00:00:00:0Z'
    end

    assert !Fabricate.build(:ethiface, :address => '00:00:00:00:00:0Z').valid?
  end
end
