require File.dirname(__FILE__)+'/test_helper'

class FiresTest < Test::Unit::TestCase
  def setup
    @group = create_group
    @project = create_project
    @james = create_person(:project => @project, :email => 'james@giraffesoft.ca')
    @mat   = create_person(:project => @project, :email => 'mat@giraffesoft.ca')
  end
  
  def test_should_fire_the_appropriate_callback
    @list = List.new(hash_for_list(:author => @james));
    TimelineEvent.expects(:create!).with(:project => @project, :actor => @james, :subject => @list, :event_type => 'list_created_or_updated')
    @list.save
    TimelineEvent.expects(:create!).with(:project => @project, :actor => @mat, :subject => @list, :event_type => 'list_created_or_updated')
    @list.author = @mat
    @list.save
  end

  def test_should_fire_event_with_secondary_subject
    @list = List.new(hash_for_list(:author => @james));
    TimelineEvent.stubs(:create!)
    @list.save
    @comment = Comment.new(:body => 'cool list!', :author => @mat, :list => @list)
    TimelineEvent.expects(:create!).with(:project           => @project,
                                         :actor             => @mat, 
                                         :subject           => @comment, 
                                         :secondary_subject => @list, 
                                         :event_type        => 'comment_created')
    @comment.save
  end

  def test_exception_raised_if_on_missing
    # This needs to be tested with should_raise, to check out the msg content
    assert_raise(ArgumentError) do
      some_class = Class.new(ActiveRecord::Base)
      some_class.class_eval do
        attr_accessor :someone
        fires :some_event, :actor => :someone
      end
    end
  end

  def test_should_only_fire_if_the_condition_evaluates_to_true
    TimelineEvent.expects(:create!).with(:project => @project, :actor => @mat, :subject => @james, :event_type => 'follow_created')
    @james.new_watcher = @mat
    @james.save
  end
  
  def test_should_not_fire_if_the_if_condition_evaluates_to_false
    TimelineEvent.expects(:create!).never
    @james.new_watcher = nil
    @james.save
  end
  
  def test_should_fire_event_with_symbol_based_if_condition_that_is_true
    @james.fire = true
    TimelineEvent.expects(:create!).with(:project => @project, :subject => @james, :event_type => 'person_updated')
    @james.save
  end
  
  def test_should_fire_event_with_symbol_based_if_condition
    @james.fire = false
    TimelineEvent.expects(:create!).never
    @james.save
  end

  def test_should_set_secondary_subject_to_self_when_requested
    @list = List.new(hash_for_list(:author => @james))
    TimelineEvent.expects(:create!).with(:project           => @project,
                                         :actor             => @james,
                                         :subject           => @list,
                                         :secondary_subject => @list,
                                         :event_type        => 'list_created_or_updated')
    @list.save
    @comment = Comment.new(:body => 'cool list!', :author => @mat, :list => @list)
    TimelineEvent.expects(:create!).with(:project           => @project,
                                         :actor             => @mat,
                                         :subject           => @comment,
                                         :secondary_subject => @comment,
                                         :event_type        => 'comment_created')
    @comment.save
    TimelineEvent.expects(:create!).with(:project           => @project,
                                         :actor             => @mat, 
                                         :subject           => @list, 
                                         :secondary_subject => @comment, 
                                         :event_type        => 'comment_deleted')
    @comment.destroy
  end
  
  def test_should_create_scoped_event
    @project_new = create_project(:group=>@group, :name=>"test inc.")
    @person_new = Person.new(hash_for_person(:project => @project, :email => 'john@giraffesoft.ca'))
    TimelineEvent.expects(:create!).with(:extra_scope           => @group,
                                         :subject         => @person,
                                         :event_type      => 'person_created')
    @person_new.save
    @person_new = Person.new(hash_for_person(:email => 'bob@giraffesoft.ca'))
    TimelineEvent.expects(:create!).never
    @person_new.save
    
  end
end
