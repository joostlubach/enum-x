require 'spec_helper'

describe EnumX do

  # Stub the enum registry.
  let(:registry) { EnumX::Registry.new }
  before { EnumX.stub(:registry).and_return(registry) }

  describe '.define and .undefine' do

    it "should raise an error if a non-existing enum is obtained through a method call" do
      expect { EnumX.test_enum }.to raise_error(NameError)
    end
    it "should return nil if a non-existing enum is obtained through an indexer" do
      EnumX[:test_enum].should == nil
    end

    it "should load an enum when it is defined" do
      EnumX.define :test_enum, %w[ one two ]

      EnumX[:test_enum].should be_a(EnumX)
      EnumX.test_enum.should be_a(EnumX)
    end

    it "should not load an enum when it is subsequently undefined" do
      EnumX.define :test_enum, %w[ one two ]
      EnumX.undefine :test_enum

      EnumX[:test_enum].should == nil
      expect { EnumX.test_enum.should be_a(EnumX) }.to raise_error(NameError)
    end
  end

  describe '.load_enums' do
    before { EnumX.stub(:load_paths).and_return(%w[ one.yml ]) }

    it "should load the right enums" do
      YAML.should_receive(:load_file).with('one.yml').and_return(
        'enum_one' => %w[ one two three ]
      )
      EnumX.send :load_enums

      EnumX[:enum_one].should be_a(EnumX)
      EnumX[:enum_one].values.should == [ :one, :two, :three ]
    end
  end

  describe 'accessing' do
    before { EnumX.define(:test_enum, %w[ one two ]) }

    it "should load the enum through an indexer" do
      EnumX[:test_enum].should be_a(EnumX)
      EnumX[:test_enum].values.should == [ :one, :two ]
    end
    it "should load the same enum through a string index" do
      EnumX['test_enum'].should be(EnumX[:test_enum])
    end
    it "should load the same enum through a method call" do
      EnumX.test_enum.should be(EnumX[:test_enum])
    end
  end

  describe "test_enum" do

    let(:test_enum) { EnumX.new(:test_enum, %w[ one two ] + [{ :value => 'three', :number => '3' }]) }

    it "should have a 3-item values array" do
      test_enum.values.should be_a(Array)
      test_enum.values.should have(3).items
      test_enum.values[0].should be_a(EnumX::Value)
    end

    describe "array conversion" do
      specify { test_enum.to_a.should == test_enum.values }
      specify { test_enum.to_ary.should == test_enum.values }
    end

    describe "value accessing" do
      it "should retrieve value :one correctly" do
        test_enum[:one].should be_a(EnumX::Value)
        test_enum[:one].value.should == 'one'
      end

      it "should retrieve nil for an unexisting value" do
        test_enum[:four].should be_nil
      end

      it "should allow accessing by integer" do
        test_enum = EnumX.new(:test_enum, [ 50, 100 ])
        test_enum[50].should be_a(EnumX::Value)
        test_enum[50].to_s.should == '50'
      end

      it "should have indifferent access" do
        test_enum['one'].should be(test_enum[:one])
      end
    end

    describe '#dup' do
      let(:duplicate) { test_enum.dup }
      specify { duplicate.name.should == 'test_enum' }

      it "should have the same values array, including specific format outputs" do
        duplicate.values.should be_a(Array)
        duplicate.should have(3).values
        duplicate.values[2].to_number.should == '3'
      end
    end

    describe '#without' do
      let(:duplicate) { test_enum.without(:one) }
      specify { duplicate.name.should == 'test_enum' }

      specify { duplicate.should have(2).values }

      specify { duplicate.values.should_not include('one') }
      specify { duplicate.values.should include('two') }
      specify { duplicate.values.should include('three') }

      it "should have the specific format output for three" do
        duplicate.values[1].to_number.should == '3'
      end
    end

    describe '#only' do
      let(:duplicate) { test_enum.only(:two, :three) }
      specify { duplicate.name.should == 'test_enum' }

      specify { duplicate.should have(2).values }

      specify { duplicate.values.should_not include('one') }
      specify { duplicate.values.should include('two') }
      specify { duplicate.values.should include('three') }

      it "should have the specific format output for three" do
        duplicate.values[1].to_number.should == '3'
      end
    end

    describe '#extend!' do
      it "should add one new value to the enum" do
        test_enum.extend!('four')

        expect(test_enum).to have(4).values
        expect(test_enum.values).to include('four')
      end

      it "should add the given values to the enum" do
        test_enum.extend!('four', 'five')

        expect(test_enum).to have(5).values
        expect(test_enum.values).to include('four')
        expect(test_enum.values).to include('five')
      end
    end

    describe EnumX::Value do

      let(:simple_value) { test_enum.values[0] }
      let(:complex_value) { test_enum.values[2] }

      specify { simple_value.enum.should be(test_enum) }

      it "should require an enum" do
        expect{ EnumX::Value.new(nil, :test) }.to raise_error(ArgumentError)
      end
      it "should require a value if a hash is specified" do
        expect{ EnumX::Value.new(test_enum, { :test => :a }) }.to raise_error(/key :value is required/)
      end

      specify { simple_value.value.should == 'one' }
      specify { simple_value.symbol.should == :one }
      specify { simple_value.to_s.should == 'one' }
      specify { simple_value.to_sym.should == :one }
      specify { simple_value.to_number.should == 'one' }
      specify { simple_value.to_xml.should == 'one' }
      specify { simple_value.to_json.should == '"one"' }
      specify { simple_value.hash.should == 'one'.hash }

      specify { complex_value.value.should == 'three' }
      specify { complex_value.symbol.should == :three }
      specify { complex_value.to_s.should == 'three' }
      specify { complex_value.to_sym.should == :three }
      specify { complex_value.to_number.should == '3' }
      specify { complex_value.to_xml.should == 'three' }
      specify { complex_value.to_json.should == '"three"' }
      specify { complex_value.hash.should == 'three'.hash }

      describe 'duplication' do
        context "with a new enum owner" do
          let(:other_enum) { EnumX.new(:test_enum, {}) }
          let(:duplicate) { complex_value.dup(other_enum) }

          specify { duplicate.value.should == 'three' }

          it "should update the enum reference" do
            duplicate.enum.should be(other_enum)
          end

          it "should keep the specific format output" do
            duplicate.to_number.should == '3'
          end
        end
        context "without a new enum owner" do
          let(:duplicate) { complex_value.dup }
          it "should keep the original enum reference" do
            duplicate.enum.should be(test_enum)
          end
        end
      end

      describe '#==' do
        specify { simple_value.should == 'one' }
        specify { simple_value.should == EnumX::Value.new(test_enum, 'one') }
        specify { simple_value.should == EnumX::Value.new(test_enum, :one) }

        specify { complex_value.should == 'three' }
        specify { complex_value.should == EnumX::Value.new(test_enum, 'three') }
        specify { complex_value.should == EnumX::Value.new(test_enum, :three) }
        specify { complex_value.should == EnumX::Value.new(test_enum, { :value => 'three' }) }
      end

      describe "mnemonics" do

        it "should respond to any value interrogation method for all the enum values" do
          simple_value.should respond_to(:one?)
          simple_value.should respond_to(:two?)
          simple_value.should respond_to(:three?)

          simple_value.should_not respond_to(:three)
          simple_value.should_not respond_to(:four?)
        end

        it "should reflect the current value's status" do
          simple_value.one?.should == true
          simple_value.two?.should == false
          simple_value.three?.should == false

          complex_value.one?.should == false
          complex_value.two?.should == false
          complex_value.three?.should == true
        end

      end

      describe "translation" do
        before { I18n.should_receive(:translate).with('one', :scope => [ :enums, 'test_enum' ], :default => 'one').and_return('One') }
        specify { simple_value.translate.should == 'One' }
      end
      describe "translation!" do
        before { I18n.should_receive(:translate).with('one', :scope => [ :enums, 'test_enum' ], :raise => true).and_return('One') }
        specify { simple_value.translate!.should == 'One' }
      end

      describe "use in case statements" do
        # Note - the case example is superfluous as the '===' method implies that it works with case statements. It's given here
        # as a real life example of its usage.

        context "using a symbol" do
          let(:result) do
            case test_enum[:one]
            when :one then true
            else false
            end
          end
          specify { :one.should === test_enum[:one] }
          specify { result.should == true }
        end
        context "using a string" do
          let(:result) do
            case test_enum[:one]
            when 'one' then true
            else false
            end
          end
          specify { 'one'.should === test_enum[:one] }
          specify { result.should == true }
        end
      end

      describe 'YAML conversion' do
        before { EnumX.stub(:[]).and_return(EnumX.new(:test_enum, %w[ one two ])) }

        context "to yaml" do
          specify { simple_value.to_yaml.should == "--- one\n...\n" }
        end

      end

    end

  end
end