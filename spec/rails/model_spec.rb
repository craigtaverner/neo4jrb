require File.join(File.dirname(__FILE__), '..', 'spec_helper')

# Specs written by Nick Sieger and modified by Andreas Ronge

describe Neo4j::Model do

  describe "new" do
    before :each do
      @model = Neo4j::Model.new
    end
    subject { @model }

    it { should_not be_persisted }

    it "should allow access to properties before it is saved" do
      @model["fur"] = "none"
      @model["fur"].should == "none"
    end

    it "validation is performed when properties are changed" do
      v = IceCream.new
      v.should_not be_valid
      v.flavour = 'vanilla'
      v.should be_valid
    end

    it "validation is performed after save" do
      v = IceCream.new(:flavour => 'vanilla')
      v.save
      v.should be_valid
    end


    it "accepts a hash of properties which will be validated" do
      v = IceCream.new(:flavour => 'vanilla')
      v.should be_valid
    end


    it "save should create a new node" do
      v = IceCream.new(:flavour => 'q')
      v.save
      Neo4j::Node.should exist(v)
    end

    it "has nil as id befored saved" do
      v = IceCream.new(:flavour => 'andreas')
      v.id.should == nil
    end

  end

  describe "load" do
    it "should load a previously stored node" do
      model = Neo4j::Model.create
      result = Neo4j::Model.load(model.id)
      result.should == model
      result.should be_persisted
    end
  end


  describe "transaction" do
    it "runs a block in a transaction" do
      id = IceCream.transaction do
        a = IceCream.create :flavour => 'vanilla'
        a.ingrediences << Neo4j::Node.new
        a.id
      end
      IceCream.load(id).should_not be_nil
    end

    it "takes a 'tx' parameter that can be used to rollback the transaction" do
      id = IceCream.transaction do |tx|
        a = IceCream.create :flavour => 'vanilla'
        a.ingrediences << Neo4j::Node.new
        tx.fail
        a.id
      end
      IceCream.load(id).should be_nil
    end
  end

  describe "save" do
    it "stores a new model in the database" do
      model = IceCream.new
      model.flavour = "vanilla"
      model.save
      model.should be_persisted
      IceCream.load(model.id).should == model
    end

    it "stores a created and modified model in the database" do
      model = IceCream.new
      model.flavour = "vanilla"
      model.save
      model.should be_persisted
      IceCream.load(model.id).should == model
    end

    it "does not save the model if it is invalid" do
      model = IceCream.new
      model.save.should_not be_true
      model.should_not be_valid

      model.should_not be_persisted
      model.id.should be_nil
    end

    it "new_record? is false before saved and true after saved (if saved was successful)" do
      model = IceCream.new(:flavour => 'vanilla')
      model.should be_new_record
      model.save.should be_true
      model.should_not be_new_record
    end

    it "does not modify the attributes if validation fails when run in a transaction" do
      model = IceCream.create(:flavour => 'vanilla')

      IceCream.transaction do
      	model.flavour = "horse"
      	model.should be_valid
      	model.save
      	
        model.flavour = nil
        model.flavour.should be_nil
        model.should_not be_valid
        model.save
        
        Neo4j::Rails::Transaction.fail
      end

      model.reload.flavour.should == 'vanilla'
    end
  end


  describe "error" do
    it "the validation method 'errors' returns the validation errors" do
      p = IceCream.new
      p.should_not be_valid
      p.errors.keys[0].should == :flavour
      p.flavour = 'vanilla'
      p.should be_valid
      p.errors.size.should == 0
    end
  end

  describe "ActiveModel::Dirty" do

    it "implements attribute_changed?, _change, _changed, _was, _changed? methods" do
      p = IceCream.new
      p.should_not be_changed
      p.flavour = 'kalle'
      p.should be_changed
      p.flavour_changed?.should == true
      p.flavour_change.should == [nil, 'kalle']
      p.flavour_was.should == nil
      p.flavour_changed?.should be_true
      p.flavour_was.should == nil

      p.flavour = 'andreas'
      p.flavour_change.should == ['kalle', 'andreas']
      p.save
      p.should_not be_changed
    end
  end

  describe "find" do
    it "should load all nodes of that type from the database" do
      model = IceCream.create :flavour => 'vanilla'
      IceCream.all.should include(model)
    end

    it "should find the node given it's id" do
      model = IceCream.create(:flavour => 'thing')
      IceCream.find(model.neo_id.to_s).should == model
    end


    it "should find a model by one of its attributes" do
      model = IceCream.create(:flavour => 'vanilla')
      IceCream.find("flavour: vanilla").should == model
    end
    
    it "should only find two by same attribute" do
      m1 = IceCream.create(:flavour => 'vanilla')
      m2 = IceCream.create(:flavour => 'vanilla')
      m3 = IceCream.create(:flavour => 'fish')
      IceCream.all("flavour: vanilla").size.should == 2
    end
  end

  describe "destroy" do
    before :each do
      @model = Neo4j::Model.create
    end

    it "should remove the model from the database" do
      id = @model.neo_id
      @model.destroy
      Neo4j::Node.load(id).should be_nil
    end
  end

  describe "create" do

    it "should save the model and return it" do
      model = Neo4j::Model.create
      model.should be_persisted
    end

    it "should accept attributes to be set" do
      model = Neo4j::Model.create :name => "Nick"
      model[:name].should == "Nick"
    end

    it "bang version should raise an exception if save returns false" do
      expect { IceCream.create! }.to raise_error(Neo4j::Model::RecordInvalidError)
    end

    it "bang version should NOT raise an exception" do
      icecream = IceCream.create! :flavour => 'vanilla'
      icecream.flavour.should == 'vanilla'
    end

    it "should run before and after create callbacks" do
      class RunBeforeAndAfterCreateCallbackModel < Neo4j::Rails::Model
        property :created
        before_create :timestamp

        def timestamp
          self.created = "yes"
          fail "Expected new record" unless new_record?
        end

        after_create :mark_saved
        attr_reader :saved

        def mark_saved
          @saved = true
        end
      end
      model = RunBeforeAndAfterCreateCallbackModel.create!
      model.created.should_not be_nil
      model.saved.should_not be_nil
    end

    it "should run before and after save callbacks" do
      class RunBeforeAndAfterSaveCallbackModel < Neo4j::Rails::Model
        property :created
        before_save :timestamp

        def timestamp
          self.created = "yes"
          fail "Expected new record" unless new_record?
        end

        after_save :mark_saved
        attr_reader :saved

        def mark_saved
          @saved = true
        end
      end

      model = RunBeforeAndAfterSaveCallbackModel.create!
      model.created.should_not be_nil
      model.saved.should_not be_nil
    end

    it "should run before and after new & save callbacks" do
      class RunBeforeAndAfterNewAndSaveCallbackModel < Neo4j::Rails::Model
        property :created
        before_save :timestamp

        def timestamp
          self.created = "yes"
          fail "Expected new record" unless new_record?
        end

        after_save :mark_saved
        attr_reader :saved

        def mark_saved
          @saved = true
        end
      end

      model = RunBeforeAndAfterNewAndSaveCallbackModel.new
      model.save
      model.created.should_not be_nil
      model.saved.should_not be_nil
    end

  end

  describe "update_attributes" do
    it "should save the attributes" do
      model = Neo4j::Model.new
      model.update_attributes(:a => 1, :b => 2).should be_true
      model[:a].should == 1
      model[:b].should == 2
    end

    it "should not update the model if it is invalid" do
      class UpdatedAttributesModel < Neo4j::Rails::Model
        property :name
        validates_presence_of :name
      end
      model = UpdatedAttributesModel.create!(:name => "vanilla")
      model.update_attributes(:name => nil).should be_false
      model.reload.name.should == "vanilla"
    end
  end

  describe "properties" do
    it "not required to run in a transaction (will create one)" do
      cream = IceCream.create :flavour => 'x'
      cream.flavour = 'vanilla'

      cream.flavour.should == 'vanilla'
      cream.should exist
    end

    it "should reuse the same transaction - not create a new one if one is already available" do
      cream = nil
      IceCream.transaction do
        cream = IceCream.create :flavour => 'x'
        cream.flavour = 'vanilla'
        cream.should exist

        # rollback the transaction
        Neo4j::Rails::Transaction.fail
      end

      cream.should_not exist
    end
  end

  describe "Neo4j::Rails::Validations::UniquenessValidator" do
    before(:all) do
      class ValidThing < Neo4j::Model
        index :email
        validates :email, :uniqueness => true
      end
      @klass = ValidThing
    end

    it "have correct kind" do
      Neo4j::Rails::Validations::UniquenessValidator.kind.should == :uniqueness
    end
    it "should not allow to create two nodes with unique fields" do
      a = @klass.create(:email => 'abc@se.com')
      b = @klass.new(:email => 'abc@se.com')

      b.save.should be_false
      b.errors.size.should == 1
    end

    it "should allow to create two nodes with not unique fields" do
      @klass.create(:email => 'abc@gmail.copm')
      b = @klass.new(:email => 'ab@gmail.com')

      b.save.should_not be_false
      b.errors.size.should == 0
    end

  end

  describe "attr_accessible" do
    before(:all) do
      @klass = create_model do
        attr_accessor :name, :credit_rating
        attr_protected :credit_rating
      end
    end

    it "given attributes are sanitized before assignment in method: attributes" do
      customer = @klass.new
      customer.attributes = {"name" => "David", "credit_rating" => "Excellent"}
      customer.name.should == 'David'
      customer.credit_rating.should be_nil

      customer.credit_rating= "Average"
      customer.credit_rating.should == 'Average'
    end

    it "given attributes are sanitized before assignment in method: new" do
      customer = @klass.new("name" => "David", "credit_rating" => "Excellent")
      customer.name.should == 'David'
      customer.credit_rating.should be_nil

      customer.credit_rating= "Average"
      customer.credit_rating.should == 'Average'
    end

    it "given attributes are sanitized before assignment in method: create" do
      customer = @klass.create("name" => "David", "credit_rating" => "Excellent")
      customer.name.should == 'David'
      customer.credit_rating.should be_nil

      customer.credit_rating= "Average"
      customer.credit_rating.should == 'Average'
    end

    it "given attributes are sanitized before assignment in method: update_attributes" do
      customer = @klass.new
      customer.update_attributes("name" => "David", "credit_rating" => "Excellent")
      customer.name.should == 'David'
      customer.credit_rating.should be_nil

      customer.credit_rating= "Average"
      customer.credit_rating.should == 'Average'
    end
  end

  describe "has_one, has_n, incoming" do
    before(:all) do
      item = create_model do
        property :name
        validates :name, :presence => true
        def to_s
          "Item #{name} class: #{self.class}"
        end
      end

      @order = create_model do
        property :name
        has_n(:items).to(item)
        validates :name, :presence => true
        def to_s
          "Order #{name} class: #{self.class}"
        end
      end

      @item = item # used as closure
      @item.has_n(:orders).from(@order, :items)
    end

    it "add nodes without save should only store it in memory" do
      order = @order.new :name => 'order'
      item =  @item.new :name => 'item'

      # then
      item.orders << order
      item.orders.should include(order)
      Neo4j.all_nodes.should_not include(item)
      Neo4j.all_nodes.should_not include(order)
    end

    it "add nodes with save should store it in db" do
      order = @order.new :name => 'order'
      item  = @item.new :name => 'item'

      # then
      item.orders << order
      item.orders.should include(order)
      item.save
      Neo4j.all_nodes.should include(item)
      Neo4j.all_nodes.should include(order)
      item.reload
      item.orders.should include(order)
    end

  end  

  describe "has_one, has_n, outgoing" do
    it "add nodes to a has_one method with the #new method" do
      member = Member.new
      avatar = Avatar.new
      member.avatar = avatar
      member.avatar.should be_kind_of(Avatar)
      member.save
      member.avatar.id.should_not be_nil
    end

    it "adding nodes to a has_n method created with the #new method" do
      icecream = IceCream.new
      suger = Ingredience.new :name => 'suger'
      icecream.ingrediences << suger
      icecream.ingrediences.should include(suger)
    end

    it "adding nodes using outgoing should work for models created with the #new method" do
      icecream = IceCream.new
      suger = Ingredience.new :name => 'suger'
      icecream.outgoing(:ingrediences) << suger
      icecream.outgoing(:ingrediences).should include(suger)
    end

    it "saving the node should create all the nested nodes" do
      icecream = IceCream.new(:flavour => 'vanilla')
      suger  = Ingredience.new :name => 'suger'
      butter = Ingredience.new :name => 'butter'

      icecream.ingrediences << suger << butter
      icecream.ingrediences.should include(suger, butter)

      suger.neo_id.should == nil
      icecream.save.should be_true

      # then
      suger.neo_id.should_not be_nil
      icecream.ingrediences.should include(suger, butter)
      icecream.ingrediences.first.should be_kind_of(Ingredience)

      # make sure the nested nodes were properly saved
      ice = IceCream.load(icecream.neo_id)
      ice.ingrediences.should include(suger, butter)
      icecream.ingrediences.first.should be_kind_of(Ingredience)
    end

    it "should not save nested nodes if it was not valid" do
      icecream = IceCream.new # not valid
      suger  = Ingredience.new :name => 'suger'
      butter = Ingredience.new :name => 'butter'

      icecream.ingrediences << suger << butter
      icecream.ingrediences.should include(suger, butter)

      suger.neo_id.should == nil
      icecream.save.should be_false

      # then
      icecream.ingrediences.should include(suger, butter)

      suger.neo_id.should == nil
   end

   it "should return false if one of the nested nodes is invalid when saving all of them" do
      suger  = Ingredience.new :name => 'suger'
      icecream2 = IceCream.new # not valid

      # when
      suger.outgoing(:related_icecreams) << icecream2

      # then
      suger.save.should be_false
    end

    it "errors should contain aggregated errors if one of the nested nodes is invalid when saving all of them" do
       suger  = Ingredience.new :name => 'suger'
       icecream2 = IceCream.new # not valid

       # when
       suger.outgoing(:related_icecreams) << icecream2

       # then
       suger.save
       suger.errors[:related_icecreams].first.should include(:flavour)
     end

    describe "nested nodes two level deep" do
      before(:all) do
        @clazz = create_model do
          property :name
          has_n :knows
          validates :name, :presence => true
        end
      end

      it "when one nested node is invalid it should not save any nodes" do
        jack  = @clazz.new(:name => 'jack')
        carol = @clazz.new(:name => 'carol')
        bob   = @clazz.new # invalid

        jack.knows << carol
        carol.knows << bob
        jack.knows << bob

        lambda do
          jack.save.should be_false
        end.should_not change([*Neo4j.all_nodes], :size)

        finish_tx
        Neo4j.all_nodes.should_not include(jack)
        Neo4j.all_nodes.should_not include(bob)
        Neo4j.all_nodes.should_not include(carol)
      end

      it "when one nested node is invalid it should not update any nodes" do
        jack  = @clazz.new(:name => 'jack')
        carol = @clazz.new(:name => 'carol')
        bob   = @clazz.new # invalid

        jack.knows << carol
        jack.save! # save all

        # when
        jack.name = 'changed'
        jack.knows << bob # invalid

        # then
        jack.save.should be_false
        jack.knows.should include(carol)
        jack.knows.should include(bob)
        jack.reload
        jack.knows.should include(carol)
        jack.knows.should_not include(bob)
        jack.name.should == 'jack'
      end

      it "only when all nested nodes are valid all the nodes will be saved" do
        jack  = @clazz.new(:name => 'jack')
        carol = @clazz.new(:name => 'carol')
        bob   = @clazz.new(:name => 'bob')

        jack.knows << carol
        carol.knows << bob
        jack.knows << bob

        lambda do
          jack.save.should be_true
        end.should_not change([*Neo4j.all_nodes], :size).by(3)

        finish_tx
        Neo4j.all_nodes.should include(jack, carol, bob)
      end

    end


    describe "accepts_nested_attributes_for" do
      it "create one-to-one " do
        params = {:member => {:name => 'Jack', :avatar_attributes => {:icon => 'smiling'}}}
        member = Member.create(params[:member])
        member.avatar.icon.should == 'smiling'

        member = Member.new(params[:member])
        member.save
        member.avatar.icon.should == 'smiling'
      end


      it "create one-to-one  - it also allows you to update the avatar through the member:" do
        params = {:member => {:name => 'Jack', :avatar_attributes => {:icon => 'smiling'}}}
        member = Member.create(params[:member])

        params = {:member => {:avatar_attributes => {:id => member.avatar.id, :icon => 'sad'}}}
        member.update_attributes params[:member]
        member.avatar.icon.should == 'sad'
      end

      it "create one-to-one  - when you add the _destroy key to the attributes hash, with a value that evaluates to true, you will destroy the associated model" do
        params = {:member => {:name => 'Jack', :avatar_attributes => {:icon => 'smiling'}}}
        member = Member.create(params[:member])
        member.avatar.should_not be_nil

        # when
        member.avatar_attributes = {:id => member.avatar.id, :_destroy => '1'}
        member.save
        member.avatar.should be_nil
      end

      it "create one-to-one  - when you add the _destroy key of value '0' to the attributes hash you will NOT destroy the associated model" do
        params = {:member => {:name => 'Jack', :avatar_attributes => {:icon => 'smiling'}}}
        member = Member.create(params[:member])
        member.avatar.should_not be_nil

        # when
        member.avatar_attributes = {:id => member.avatar.id, :_destroy => '0'}
        member.save
        member.avatar.should_not be_nil
      end

      it "create one-to_many - You can now set or update attributes on an associated post model through the attribute hash" do
        # For each hash that does not have an id key a new record will be instantiated, unless the hash also contains a _destroy key that evaluates to true.
        params = {:member => {
            :name => 'joe', :posts_attributes => [
                {:title => 'Kari, the awesome Ruby documentation browser!'},
                {:title => 'The egalitarian assumption of the modern citizen'},
                {:title => '', :_destroy => '1'} # this will be ignored
            ]
        }}

        member = Member.create(params[:member])
        member.posts.size.should == 2
        member.posts.first.title.should == 'Kari, the awesome Ruby documentation browser!'
        member.posts[1].title.should == 'The egalitarian assumption of the modern citizen'

        member = Member.new(params[:member])
        member.posts.first.title.should == 'Kari, the awesome Ruby documentation browser!'
        member.posts[1].title.should == 'The egalitarian assumption of the modern citizen'
      end


      it ":reject_if proc will silently ignore any new record hashes if they fail to pass your criteria." do
        params = {:member => {
            :name => 'joe', :valid_posts_attributes => [
                {:title => 'Kari, the awesome Ruby documentation browser!'},
                {:title => 'The egalitarian assumption of the modern citizen'},
                {:title => ''} # this will be ignored because of the :reject_if proc
            ]
        }}

        member = Member.create(params[:member])
        member.valid_posts.length.should == 2
        member.valid_posts.first.title.should == 'Kari, the awesome Ruby documentation browser!'
        member.valid_posts[1].title.should == 'The egalitarian assumption of the modern citizen'
      end


      it ":reject_if also accepts a symbol for using methods" do
        params = {:member => {
            :name => 'joe', :valid_posts2_attributes => [
                {:title => 'Kari, the awesome Ruby documentation browser!'},
                {:title => 'The egalitarian assumption of the modern citizen'},
                {:title => ''} # this will be ignored because of the :reject_if proc
            ]
        }}

        member = Member.create(params[:member])
        member.valid_posts2.length.should == 2
        member.valid_posts2.first.title.should == 'Kari, the awesome Ruby documentation browser!'
        member.valid_posts2[1].title.should == 'The egalitarian assumption of the modern citizen'

        member = Member.new(params[:member])
        member.valid_posts2.first.title.should == 'Kari, the awesome Ruby documentation browser!'
        member.valid_posts2[1].title.should == 'The egalitarian assumption of the modern citizen'
        member.save
        member.valid_posts2.length.should == 2
        member.valid_posts2.first.title.should == 'Kari, the awesome Ruby documentation browser!'
        member.valid_posts2[1].title.should == 'The egalitarian assumption of the modern citizen'
      end


      it "If the hash contains an id key that matches an already associated record, the matching record will be modified:" do
        params            = {:member => {
            :name => 'joe', :posts_attributes => [
                {:title => 'Kari, the awesome Ruby documentation browser!'},
                {:title => 'The egalitarian assumption of the modern citizen'},
                {:title => '', :_destroy => '1'} # this will be ignored
            ]
        }}

        member            = Member.create(params[:member])

        # when
        id1               = member.posts[0].id
        id2               = member.posts[1].id

        member.attributes = {
            :name             => 'Joe',
            :posts_attributes => [
                {:id => id1, :title => '[UPDATED] An, as of yet, undisclosed awesome Ruby documentation browser!'},
                {:id => id2, :title => '[UPDATED] other post'}
            ]
        }

        # then
        member.posts.first.title.should == '[UPDATED] An, as of yet, undisclosed awesome Ruby documentation browser!'
        member.posts[1].title.should == '[UPDATED] other post'
      end
    end
  end

end
