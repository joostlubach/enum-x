require 'spec_helper'

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
    EnumX.stub(:[]) { |name| case name.to_s when 'statuses' then statuses when 'alternate_statuses' then alternate_statuses else roles end }
    EnumX.stub(:statuses) { statuses }
    EnumX.stub(:alternate_statuses) { alternate_statuses }
    EnumX.stub(:roles) { roles }
  end

  describe 'convenience accessors' do

    it "should create a convenience accessor for the enum (single)" do
      klass.class_eval { attr_accessor :status; enum :status }
      klass.statuses.should be(statuses)
    end

    it "should create a convenience accessor to an alternate enum if provided" do
      klass.class_eval { attr_accessor :status; enum :status, :alternate_statuses }
      klass.statuses.should be(alternate_statuses)
    end

    it "should create a convience accessor to an ad-hoc enum" do
      use_this_enum = EnumX.new(:alternative, %w[ one two three ])
      klass.class_eval { attr_accessor :status; enum :status, use_this_enum }
      klass.statuses.should be(use_this_enum)
    end

    it "should create a convenience accessor for the enum flags" do
      klass.class_eval { attr_accessor :roles; enum :roles, :flags => true }
      klass.roles.should be(roles)
    end

    it "should be accessible on a subclass as well" do
      subclass = Class.new(klass)
      klass.class_eval { attr_accessor :status; enum :status }
      subclass.statuses.should be(statuses)
    end

  end

  describe "reader registration" do
    context "when the class has an existing attribute_reader" do
      before { klass.class_eval { attr_accessor :status; enum :status } }

      it "should use the original reader upon reading" do
        object.should_receive(:status_without_enums).and_return(:new)
        object.status.should be(EnumX.statuses[:new])
      end
      it "should call the original writer upon writing" do
        object.should_receive(:status_without_enums=).with(EnumX.statuses[:new])
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
        object.should_receive(:read_attribute).with(:status).and_return(:new)
        object.status.should be(EnumX.statuses[:new])
      end
      it "should call the original writer upon writing" do
        object.should_receive(:write_attribute).with(:status, EnumX.statuses[:new])
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
        object.should be_valid
      end

      it "shoult not allow any other value" do
        object.status = :doesnotexist
        object.should_not be_valid
      end

      it "should allow a blank value by default" do
        object.status = nil
        object.should be_valid
      end

      it "should not allow a blank value if :allow_blank => false" do
        klass.class_eval { attr_accessor :status2; enum :status2, :status, :allow_blank => false }
        object.status2 = nil
        object.should_not be_valid
      end

    end

    context "reading" do

      it "should convert a Symbol into an enum value" do
        object.instance_variable_set('@status', :new)
        object.status.should be(EnumX.statuses[:new])
      end

      it "should convert a String into an enum value" do
        object.instance_variable_set('@status', 'new')
        object.status.should be(EnumX.statuses[:new])
      end

      it "should keep any EnumX::Value instance" do
        object.instance_variable_set('@status', EnumX.statuses[:new])
        object.status.should be(EnumX.statuses[:new])
      end

      it "should pass the original value if no corresponding enum value was found" do
        object.instance_variable_set('@status', :doesnotexist)
        object.status.should be_a(Symbol)
        object.status.should == :doesnotexist
      end

      it "should pass a nil value through" do
        object.instance_variable_set('@status', nil)
        object.status.should == nil
      end

    end

    context "writing" do

      it "should convert a Symbol into an enum value" do
        object.status = :new
        object.instance_variable_get('@status').should be(EnumX.statuses[:new])
      end

      it "should convert a String into an enum value" do
        object.status = 'new'
        object.instance_variable_get('@status').should be(EnumX.statuses[:new])
      end

      it "should keep any EnumX::Value instance" do
        object.status = EnumX.statuses[:new]
        object.instance_variable_get('@status').should be(EnumX.statuses[:new])
      end

      it "should pass the original value if no corresponding enum value was found" do
        object.status = :doesnotexist
        object.instance_variable_get('@status').should be_a(Symbol)
        object.instance_variable_get('@status').should == :doesnotexist
      end

      it "should pass a nil value through" do
        object.status = nil
        object.instance_variable_get('@status').should == nil
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
        object.should be_valid
      end

      it "should allow an array with only valid values" do
        object.roles = [ :admin, :user ]
        object.should be_valid
      end

      it "shoult not allow any invalid value to exist" do
        object.roles = [ :admin, :doesnotexist ]
        object.should_not be_valid
      end

      it "should allow a nil value by default" do
        object.roles = nil
        object.should be_valid
      end

      it "should allow an empty array value by default" do
        object.roles = []
        object.should be_valid
      end

      it "should not allow a nil value or empty array if :allow_blank => false" do
        klass.class_eval { attr_accessor :roles2; enum :roles2, :roles, :allow_blank => false }
        object.roles2 = nil
        object.should_not be_valid

        object.roles2 = []
        object.should_not be_valid
      end

    end

    context "reading" do

      it "should convert an array of Symbols and Strings into a value list" do
        object.instance_variable_set('@roles', [ :admin, 'user' ])
        object.roles.should be_a(EnumX::ValueList)
        object.roles.should == [ EnumX.roles[:admin], EnumX.roles[:user] ]
      end

      it "should convert a single Symbol into a value list" do
        object.instance_variable_set('@roles', :admin)
        object.roles.should be_a(EnumX::ValueList)
        object.roles.should == [ EnumX.roles[:admin] ]
      end

      it "should convert a single String into a value list" do
        object.instance_variable_set('@roles', 'admin')
        object.roles.should be_a(EnumX::ValueList)
        object.roles.should == [ EnumX.roles[:admin] ]
      end

      it "should convert a single EnumX::Value into a value list" do
        object.instance_variable_set('@roles', EnumX.roles[:admin])
        object.roles.should be_a(EnumX::ValueList)
        object.roles.should == [ EnumX.roles[:admin] ]
      end

      it "should keep any EnumX::ValueList instance" do
        list = EnumX::ValueList.new(EnumX.roles, [ :admin, :user ])
        object.instance_variable_set('@roles', list)
        object.roles.should be(list)
      end

      it "should keep invalid enum values as their originals" do
        object.instance_variable_set('@roles', [ :admin, :doesnotexist ])
        object.roles.should be_a(EnumX::ValueList)
        object.roles.should == [ EnumX.roles[:admin], :doesnotexist ]
      end

      it "should pass a nil value through" do
        object.instance_variable_set('@roles', nil)
        object.roles.should == nil
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
        klass.should_receive(:sifter).with(:roles2_include)
        klass.should_receive(:sifter).with(:roles2_exclude)
        klass.class_eval { attr_accessor :roles2; enum :roles2, :flags => true }
      end

    end

  end

  describe "mnemonics" do

    it "should create an mnemonic for each enum value (single enum)" do
      klass.class_eval { attr_accessor :status; enum :status, :mnemonics => true }

      object.status = :new
      object.new?.should == true
      object.sent?.should == false

      object.status = :sent
      object.new?.should == false
      object.sent?.should == true
    end

    it "should create an mnemonic for each enum value (flags enum)" do
      klass.class_eval { attr_accessor :roles; enum :roles, :flags => true, :mnemonics => true }

      object.roles = []
      object.admin?.should == false
      object.user?.should == false

      object.roles = [ :admin ]
      object.admin?.should == true
      object.user?.should == false

      object.roles = [ :admin, :user ]
      object.admin?.should == true
      object.user?.should == true
    end

  end

  describe EnumX::DSL::FlagsSerializer do
    let(:serializer) { EnumX::DSL::FlagsSerializer.new(EnumX.roles) }

    it "should load a pipe-separated string" do
      list = serializer.load("|admin|user|doesnotexist|")
      list.should be_a(EnumX::ValueList)
      list.should == [ EnumX.roles[:admin], EnumX.roles[:user], 'doesnotexist' ]
    end

    it "should dump a list to a pipe-separated string" do
      list = EnumX::ValueList.new(EnumX.roles, [ :admin, :user ])
      serializer.dump(list).should == "|admin|user|"
      serializer.dump("|admin|user|").should == "|admin|user|"
    end
  end

end