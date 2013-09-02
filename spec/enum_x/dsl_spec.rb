require 'spec_helper'
require 'active_model'

describe EnumX::DSL do

  let(:klass) do
    Class.new do
      include ActiveModel::Validations; include EnumX::DSL
      def self.model_name; ActiveModel::Name.new(self, nil, 'TestClass') end
    end
  end
  let(:object) { klass.new }
  let(:statuses) { EnumX.new(:statuses, %w[ new sent ]) }
  let(:alternate_statuses) { EnumX.new(:statuses, %w[ new sent delivered ]) }
  let(:roles) { EnumX.new(:roles, %w[ admin user ]) }

  before do
    allow(EnumX).to receive(:[]) { |name| case name.to_s when 'statuses' then statuses when 'alternate_statuses' then alternate_statuses else roles end }
    allow(EnumX).to receive(:statuses) { statuses }
    allow(EnumX).to receive(:alternate_statuses) { alternate_statuses }
    allow(EnumX).to receive(:roles) { roles }
  end

  describe 'convenience accessors' do

    it "should create a convenience accessor for the enum (single)" do
      klass.class_eval { attr_accessor :status; enum :status }
      expect(klass.statuses).to be(statuses)
    end

    it "should create a convenience accessor to an alternate enum if provided" do
      klass.class_eval { attr_accessor :status; enum :status, :alternate_statuses }
      expect(klass.statuses).to be(alternate_statuses)
    end

    it "should create a convience accessor to an ad-hoc enum" do
      use_this_enum = EnumX.new(:alternative, %w[ one two three ])
      klass.class_eval { attr_accessor :status; enum :status, use_this_enum }
      expect(klass.statuses).to be(use_this_enum)
    end

    it "should create a convenience accessor for the enum flags" do
      klass.class_eval { attr_accessor :roles; enum :roles, :flags => true }
      expect(klass.roles).to be(roles)
    end

    it "should be accessible on a subclass as well" do
      subclass = Class.new(klass)
      klass.class_eval { attr_accessor :status; enum :status }
      expect(subclass.statuses).to be(statuses)
    end

  end

  describe "reader registration" do
    context "when the class has an existing attribute_reader" do
      before { klass.class_eval { attr_accessor :status; enum :status } }

      it "should use the original reader upon reading" do
        expect(object).to receive(:status_without_enums).and_return(:new)
        expect(object.status).to be(EnumX.statuses[:new])
      end
      it "should call the original writer upon writing" do
        expect(object).to receive(:status_without_enums=).with(EnumX.statuses[:new])
        object.status = :new
      end
    end

    context "when the class has a read_attribute and write_attribute method (ActiveRecord)" do
      before do
        klass.class_eval do
          # These will be stubbed later.
          def read_attribute(attribute) end
          def write_attribute(attribute, value) end
          enum :status
        end
      end

      it "should use read_attribute upon reading" do
        expect(object).to receive(:read_attribute).with(:status).and_return(:new)
        expect(object.status).to be(EnumX.statuses[:new])
      end
      it "should call the original writer upon writing" do
        expect(object).to receive(:write_attribute).with(:status, EnumX.statuses[:new])
        object.status = :new
      end
    end

    context "when the class has neither" do
      it "should raise an error" do
        expect{ klass.class_eval{ enum :status } }.to raise_error(/cannot overwrite/)
      end
    end
  end

  describe "single enum" do

    before do
      klass.class_eval { attr_accessor :status; enum :status }
    end

    context "validation" do

      it "should allow any value which is any of the enum values" do
        object.status = :new
        expect(object).to be_valid
      end

      it "shoult not allow any other value" do
        object.status = :doesnotexist
        expect(object).to_not be_valid
      end

      it "should allow a blank value by default" do
        object.status = nil
        expect(object).to be_valid
      end

      it "should not allow a blank value if :allow_blank => false" do
        klass.class_eval { attr_accessor :status2; enum :status2, :status, :allow_blank => false }
        object.status2 = nil
        expect(object).to_not be_valid
      end

    end

    context "reading" do

      it "should convert a Symbol into an enum value" do
        object.instance_variable_set('@status', :new)
        expect(object.status).to be(EnumX.statuses[:new])
      end

      it "should convert a String into an enum value" do
        object.instance_variable_set('@status', 'new')
        expect(object.status).to be(EnumX.statuses[:new])
      end

      it "should keep any EnumX::Value instance" do
        object.instance_variable_set('@status', EnumX.statuses[:new])
        expect(object.status).to be(EnumX.statuses[:new])
      end

      it "should pass the original value if no corresponding enum value was found" do
        object.instance_variable_set('@status', :doesnotexist)
        expect(object.status).to be_a(Symbol)
        expect(object.status).to be(:doesnotexist)
      end

      it "should pass a nil value through" do
        object.instance_variable_set('@status', nil)
        expect(object.status).to be_nil
      end

    end

    context "writing" do

      it "should convert a Symbol into an enum value" do
        object.status = :new
        expect(object.instance_variable_get('@status')).to be(EnumX.statuses[:new])
      end

      it "should convert a String into an enum value" do
        object.status = 'new'
        expect(object.instance_variable_get('@status')).to be(EnumX.statuses[:new])
      end

      it "should keep any EnumX::Value instance" do
        object.status = EnumX.statuses[:new]
        expect(object.instance_variable_get('@status')).to be(EnumX.statuses[:new])
      end

      it "should pass the original value if no corresponding enum value was found" do
        object.status = :doesnotexist
        expect(object.instance_variable_get('@status')).to be_a(Symbol)
        expect(object.instance_variable_get('@status')).to be(:doesnotexist)
      end

      it "should pass a nil value through" do
        object.status = nil
        expect(object.instance_variable_get('@status')).to be_nil
      end

    end

  end

  describe "enum flags (multiple enum)" do

    before do
      klass.class_eval { attr_accessor :roles; enum :roles, :flags => true }
    end

    context "validation" do

      it "should allow a single value" do
        object.roles = :admin
        expect(object).to be_valid
      end

      it "should allow an array with only valid values" do
        object.roles = [ :admin, :user ]
        expect(object).to be_valid
      end

      it "shoult not allow any invalid value to exist" do
        object.roles = [ :admin, :doesnotexist ]
        expect(object).to_not be_valid
      end

      it "should allow a nil value by default" do
        object.roles = nil
        expect(object).to be_valid
      end

      it "should allow an empty array value by default" do
        object.roles = []
        expect(object).to be_valid
      end

      it "should not allow a nil value or empty array if :allow_blank => false" do
        klass.class_eval { attr_accessor :roles2; enum :roles2, :roles, :allow_blank => false }
        object.roles2 = nil
        expect(object).to_not be_valid

        object.roles2 = []
        expect(object).to_not be_valid
      end

    end

    context "reading" do

      it "should convert an array of Symbols and Strings into a value list" do
        object.instance_variable_set('@roles', [ :admin, 'user' ])
        expect(object.roles).to be_a(EnumX::ValueList)
        expect(object.roles).to eq([ EnumX.roles[:admin], EnumX.roles[:user] ])
      end

      it "should convert a single Symbol into a value list" do
        object.instance_variable_set('@roles', :admin)
        expect(object.roles).to be_a(EnumX::ValueList)
        expect(object.roles).to eq([ EnumX.roles[:admin] ])
      end

      it "should convert a single String into a value list" do
        object.instance_variable_set('@roles', 'admin')
        expect(object.roles).to be_a(EnumX::ValueList)
        expect(object.roles).to eq([ EnumX.roles[:admin] ])
      end

      it "should convert a single EnumX::Value into a value list" do
        object.instance_variable_set('@roles', EnumX.roles[:admin])
        expect(object.roles).to be_a(EnumX::ValueList)
        expect(object.roles).to eq([ EnumX.roles[:admin] ])
      end

      it "should keep any EnumX::ValueList instance" do
        list = EnumX::ValueList.new(EnumX.roles, [ :admin, :user ])
        object.instance_variable_set('@roles', list)
        expect(object.roles).to be(list)
      end

      it "should keep invalid enum values as their originals" do
        object.instance_variable_set('@roles', [ :admin, :doesnotexist ])
        expect(object.roles).to be_a(EnumX::ValueList)
        expect(object.roles).to eq([ EnumX.roles[:admin], :doesnotexist ])
      end

      it "should pass a nil value through" do
        object.instance_variable_set('@roles', nil)
        expect(object.roles).to be_nil
      end

    end

    describe 'sifters' do

      # Note - this doesn't check the syntactical correctness of the sifter. This is hard to test without
      # depending on the correct workings of Squeel. They have been manually tested.
      #
      # Usage:
      #
      #   klass.where{ sift(:roles2_include, 'admin') }.to_sql
      #   # => SELECT * FROM `<table>` WHERE `<table>`.`roles2` LIKE '%|admin|%'
      it "should create a sifter <enum>_include" do
        expect(klass).to receive(:sifter).with(:roles2_include)
        expect(klass).to receive(:sifter).with(:roles2_exclude)
        klass.class_eval { attr_accessor :roles2; enum :roles2, :flags => true }
      end

    end

  end

  describe "mnemonics" do

    it "should create an mnemonic for each enum value (single enum)" do
      klass.class_eval { attr_accessor :status; enum :status, :mnemonics => true }

      object.status = :new
      expect(object.new?).to eql(true)
      expect(object.sent?).to eql(false)

      object.status = :sent
      expect(object.new?).to eql(false)
      expect(object.sent?).to eql(true)
    end

    it "should create an mnemonic for each enum value (flags enum)" do
      klass.class_eval { attr_accessor :roles; enum :roles, :flags => true, :mnemonics => true }

      object.roles = []
      expect(object.admin?).to eql(false)
      expect(object.user?).to eql(false)

      object.roles = [ :admin ]
      expect(object.admin?).to eql(true)
      expect(object.user?).to eql(false)

      object.roles = [ :admin, :user ]
      expect(object.admin?).to eql(true)
      expect(object.user?).to eql(true)
    end

  end

  describe EnumX::DSL::FlagsSerializer do
    let(:serializer) { EnumX::DSL::FlagsSerializer.new(EnumX.roles) }

    it "should load a pipe-separated string" do
      list = serializer.load("|admin|user|doesnotexist|")
      expect(list).to be_a(EnumX::ValueList)
      expect(list).to eq([ EnumX.roles[:admin], EnumX.roles[:user], 'doesnotexist' ])
    end

    it "should dump a list to a pipe-separated string" do
      list = EnumX::ValueList.new(EnumX.roles, [ :admin, :user ])
      expect(serializer.dump(list)).to eql("|admin|user|")
      expect(serializer.dump("|admin|user|")).to eql("|admin|user|")
    end
  end

end