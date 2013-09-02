require 'spec_helper'
require 'active_support'

describe EnumX do

  # Stub the enum registry.
  let(:registry) { EnumX::Registry.new }
  before { allow(EnumX).to receive(:registry).and_return(registry) }

  describe '.define and .undefine' do

    it "should raise an error if a non-existing enum is obtained through a method call" do
      expect { EnumX.test_enum }.to raise_error(NameError)
    end
    it "should return nil if a non-existing enum is obtained through an indexer" do
      expect(EnumX[:test_enum]).to be_nil
    end

    it "should load an enum when it is defined" do
      EnumX.define :test_enum, %w[ one two ]

      expect(EnumX[:test_enum]).to be_a(EnumX)
      EnumX.test_enum.should be_a(EnumX)
    end

    it "should not load an enum when it is subsequently undefined" do
      EnumX.define :test_enum, %w[ one two ]
      EnumX.undefine :test_enum

      expect(EnumX[:test_enum]).to be_nil
      expect{ EnumX.test_enum }.to raise_error(NameError)
    end
  end

  describe '.load_enums' do
    before { allow(EnumX).to receive(:load_paths).and_return(%w[ one.yml ]) }

    it "should load the right enums" do
      # The load_file method is loaded twice because @registry is unset, though we've stubbed :registry.
      expect(YAML).to receive(:load_file).twice.with('one.yml').and_return(
        'enum_one' => %w[ one two three ]
      )

      expect(EnumX[:enum_one]).to be_a(EnumX)
      expect(EnumX[:enum_one].values).to eq([ :one, :two, :three ])
    end
  end

  describe 'accessing' do
    before { EnumX.define(:test_enum, %w[ one two ]) }

    it "should load the enum through an indexer" do
      expect(EnumX[:test_enum]).to be_a(EnumX)
      expect(EnumX[:test_enum].values).to eq([ :one, :two ])
    end
    it "should load the same enum through a string index" do
      expect(EnumX['test_enum']).to be(EnumX[:test_enum])
    end
    it "should load the same enum through a method call" do
      expect(EnumX.test_enum).to be(EnumX[:test_enum])
    end
  end

  describe "test_enum" do

    let(:test_enum) { EnumX.new(:test_enum, %w[ one two ] + [{ :value => 'three', :number => '3' }]) }

    it "should have a 3-item values array" do
      expect(test_enum).to have(3).values
      expect(test_enum.values[0]).to be_a(EnumX::Value)
    end

    describe "array conversion" do
      specify { expect(test_enum.to_a).to eql(test_enum.values) }
      specify { expect(test_enum.to_ary).to eql(test_enum.values) }
    end

    describe "value accessing" do
      it "should retrieve value :one correctly" do
        expect(test_enum[:one]).to be_a(EnumX::Value)
        expect(test_enum[:one].value).to eq('one')
      end

      it "should retrieve nil for an unexisting value" do
        expect(test_enum[:four]).to be_nil
      end

      it "should allow accessing by integer" do
        test_enum = EnumX.new(:test_enum, [ 50, 100 ])
        expect(test_enum[50]).to be_a(EnumX::Value)
        expect(test_enum[50].to_s).to eql('50')
      end

      it "should have indifferent access" do
        expect(test_enum['one']).to be(test_enum[:one])
      end
    end

    describe '#dup' do
      let(:duplicate) { test_enum.dup }
      specify { expect(duplicate.name).to eql('test_enum') }

      it "should have the same values array, including specific format outputs" do
        expect(duplicate).to have(3).values
        expect(duplicate.values[2].to_number).to eql('3')
      end
    end

    describe '#without' do
      let(:duplicate) { test_enum.without(:one) }
      specify { expect(duplicate.name).to eql('test_enum') }

      it "should have removed the value :one" do
        expect(duplicate).to have(2).values
        expect(duplicate.values).not_to include('one')
        expect(duplicate.values).to include('two')
        expect(duplicate.values).to include('three')
      end

      it "should have the specific format output for three" do
        expect(duplicate.values[1].to_number).to eql('3')
      end
    end

    describe '#only' do
      let(:duplicate) { test_enum.only(:two, :three) }
      specify { expect(duplicate.name).to eql('test_enum') }

      it "should have kept the values :two and three" do
        expect(duplicate).to have(2).values
        expect(duplicate.values).not_to include('one')
        expect(duplicate.values).to include('two')
        expect(duplicate.values).to include('three')
      end

      it "should have the specific format output for three" do
        expect(duplicate.values[1].to_number).to eql('3')
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

      it "should add values using a hash" do
        test_enum.extend!(:value => 'four', :number => '4')

        expect(test_enum).to have(4).values
        expect(test_enum.values).to include('four')
        expect(test_enum[:four].to_number).to eql('4')
      end
    end

    describe EnumX::Value do

      let(:simple_value) { test_enum.values[0] }
      let(:complex_value) { test_enum.values[2] }

      specify { expect(simple_value.enum).to be(test_enum) }

      it "should require an enum" do
        expect{ EnumX::Value.new(nil, :test) }.to raise_error(ArgumentError)
      end
      it "should require a value if a hash is specified" do
        expect{ EnumX::Value.new(test_enum, { :test => :a }) }.to raise_error(/key :value is required/)
      end

      specify { expect(simple_value.value).to eql('one') }
      specify { expect(simple_value.symbol).to eql(:one) }
      specify { expect(simple_value.to_s).to eql('one') }
      specify { expect(simple_value.to_sym).to eql(:one) }
      specify { expect(simple_value.to_number).to eql('one') }
      specify { expect(simple_value.to_xml).to eql('one') }
      specify { expect(simple_value.to_json).to eql('"one"') }
      specify { expect(simple_value.hash).to eql('one'.hash) }

      specify { expect(complex_value.value).to eql('three') }
      specify { expect(complex_value.symbol).to eql(:three) }
      specify { expect(complex_value.to_s).to eql('three') }
      specify { expect(complex_value.to_sym).to eql(:three) }
      specify { expect(complex_value.to_number).to eql('3') }
      specify { expect(complex_value.to_xml).to eql('three') }
      specify { expect(complex_value.to_json).to eql('"three"') }
      specify { expect(complex_value.hash).to eql('three'.hash) }

      describe 'duplication' do
        context "with a new enum owner" do
          let(:other_enum) { EnumX.new(:test_enum, {}) }
          let(:duplicate) { complex_value.dup(other_enum) }

          specify { expect(duplicate.value).to eql('three') }

          it "should update the enum reference" do
            expect(duplicate.enum).to be(other_enum)
          end

          it "should keep the specific format output" do
            expect(duplicate.to_number).to eql('3')
          end
        end
        context "without a new enum owner" do
          let(:duplicate) { complex_value.dup }
          it "should keep the original enum reference" do
            expect(duplicate.enum).to be(test_enum)
          end
        end
      end

      describe 'equality' do
        specify { expect(simple_value).to eq('one') }
        specify { expect(simple_value).to eq(EnumX::Value.new(test_enum, 'one')) }
        specify { expect(simple_value).to eq(EnumX::Value.new(test_enum, :one)) }

        specify { expect(simple_value).not_to eql('one') }
        specify { expect(simple_value).to eql(EnumX::Value.new(test_enum, 'one')) }
        specify { expect(simple_value).to eql(EnumX::Value.new(test_enum, :one)) }

        specify { expect(complex_value).to eq('three') }
        specify { expect(complex_value).to eql(EnumX::Value.new(test_enum, 'three')) }
        specify { expect(complex_value).to eql(EnumX::Value.new(test_enum, :three)) }
        specify { expect(complex_value).to eql(EnumX::Value.new(test_enum, { :value => 'three' })) }
      end

      describe "mnemonics" do

        it "should respond to any value interrogation method for all the enum values" do
          expect(simple_value).to respond_to(:one?)
          expect(simple_value).to respond_to(:two?)
          expect(simple_value).to respond_to(:three?)

          expect(simple_value).not_to respond_to(:three)
          expect(simple_value).not_to respond_to(:four?)
        end

        it "should reflect the current value's status" do
          expect(simple_value.one?).to be_true
          expect(simple_value.two?).to be_false
          expect(simple_value.three?).to be_false

          expect(complex_value.one?).to be_false
          expect(complex_value.two?).to be_false
          expect(complex_value.three?).to be_true
        end

      end

      describe "translate" do
        it "should translate the value, and provide a default value" do
          expect(I18n).to receive(:translate).with('one', :scope => [ :enums, 'test_enum' ], :default => 'one').and_return('One')
          expect(simple_value.translate).to eql('One')
        end

        it "should use a humanized default value using ActiveSupport if available" do
          expect(I18n).to receive(:translate).with('test_value', :scope => [ :enums, 'test_enum' ], :default => 'test value').and_return('Test Value')
          expect(EnumX::Value.new(test_enum, 'test_value').translate).to eql('Test Value')
        end

        it "should use the string version if ActiveSupport is not available" do
          tmp = ::ActiveSupport
          Object.send :remove_const, :ActiveSupport

          expect(I18n).to receive(:translate).with('test_value', :scope => [ :enums, 'test_enum' ], :default => 'test_value').and_return('Test Value')
          expect(EnumX::Value.new(test_enum, 'test_value').translate).to eql('Test Value')

          Object::ActiveSupport = tmp
        end
      end
      describe "translate!" do
        it "should translate the value, and raise an error if no translation could be made" do
          expect(I18n).to receive(:translate).with('one', :scope => [ :enums, 'test_enum' ], :raise => true).and_raise("translation not found")
          expect{ simple_value.translate! }.to raise_error("translation not found")
        end
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
          specify { expect(:one).to be === test_enum[:one] }
          specify { expect(result).to be_true }
        end
        context "using a string" do
          let(:result) do
            case test_enum[:one]
            when 'one' then true
            else false
            end
          end
          specify { expect('one').to be === test_enum[:one] }
          specify { expect(result).to be_true }
        end
      end

      describe 'YAML conversion' do
        before { allow(EnumX).to receive(:[]).and_return(EnumX.new(:test_enum, %w[ one two ])) }

        context "to yaml" do
          specify { expect(simple_value.to_yaml).to eql("--- one\n...\n") }
        end

      end

    end

  end
end