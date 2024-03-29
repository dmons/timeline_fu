require 'rubygems'
require 'active_record'
require 'mocha'
require 'test/unit'
require 'logger'

require File.dirname(__FILE__)+'/../lib/timeline_fu'

ActiveRecord::Base.configurations = {'sqlite3' => {:adapter => 'sqlite3', :database => ':memory:'}}
ActiveRecord::Base.establish_connection('sqlite3')

ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.logger.level = Logger::WARN

ActiveRecord::Schema.define(:version => 0) do
  create_table :groups do |t|
    t.string :name
  end
  
  create_table :projects do |t|
    t.string :name, :default => ""
    t.string :description, :default => ""
    t.references :group
  end

  create_table :people do |t|
    t.references :project
    t.string  :email,    :default => ''
    t.string  :password, :default => ''
  end

  create_table :lists do |t|
    t.integer :author_id
    t.string  :title
  end

  create_table :comments do |t|
    t.integer :list_id, :author_id
    t.string  :body
  end
end

class Group < ActiveRecord::Base
end

class Project < ActiveRecord::Base
  belongs_to :group
  
  has_many :people
  
end

class Person < ActiveRecord::Base
  attr_accessor :new_watcher, :fire

  belongs_to :project
  
  fires :person_created,  :on     => :create,
                          :extra_scope  => Proc.new { |person| person.project.group },
                          :if     => lambda { |person| person.project and person.project.group }

  fires :follow_created,  :on     => :update, 
                          :actor  => lambda { |person| person.new_watcher }, 
                          :if     => lambda { |person| !person.new_watcher.nil? }
                          
  
  fires :person_updated,  :on     => :update,
                          :if     => :fire?

  def fire?
    new_watcher.nil? && fire
  end
end

class List < ActiveRecord::Base
  belongs_to :author, :class_name => "Person"
  has_many :comments
  
  fires :list_created_or_updated,  :project => Proc.new { |list| list.author.project_id },
                                   :actor  => :author, 
                                   :on     => [:create, :update]
end

class Comment < ActiveRecord::Base
  belongs_to :list
  belongs_to :author, :class_name => "Person"

  fires :comment_created, :project => Proc.new { |comment| comment.list.author.project_id },
                          :actor   => :author,
                          :on      => :create,
                          :secondary_subject => :list
  fires :comment_deleted, :project => Proc.new { |comment| comment.list.author.project_id },
                          :actor   => :author,
                          :on      => :destroy,
                          :subject => :list,
                          :secondary_subject => :self
end



TimelineEvent = Class.new

class Test::Unit::TestCase
  protected
    def hash_for_group(opts = {})
      {:name => 'test'}.merge(opts)
    end
  
    def create_group(opts = {})
      Group.create!(hash_for_group(opts))
    end
  
    def hash_for_project(opts = {})
      {:name => "fantasy inc.", :description => "rails shop"}.merge(opts)
    end

    def create_project(opts = {})
      Project.create!(hash_for_project(opts))
    end

    def hash_for_list(opts = {})
      {:title => 'whatever'}.merge(opts)
    end
    
    def create_list(opts = {})
      List.create!(hash_for_list(opts))
    end
    
    def hash_for_person(opts = {})
      {:email => 'james'}.merge(opts)
    end
    
    def create_person(opts = {})
      Person.create!(hash_for_person(opts))
    end
end
