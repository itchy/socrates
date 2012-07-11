require './lib/socrates'
abort unless defined?(Socrates) and Socrates.is_a? Class

require 'rubygems'
require 'pp'
require 'bundler/setup'
require 'sequel'

Topic = Socrates::Topic

class Socrates::TopicStore
puts "--- Entering TopicStore class def"
  class << self
    attr_accessor :store  # basically a hash; path=>topic
    attr_accessor :count
  end

  @count = 0

puts "--- Reading yaml"
  @store = YAML.load(File.read("topics.yaml")) rescue {}
# @store.each_pair {|path, topic| puts "#{path} is child of #{topic.parent.pathname rescue 'root'}" }

  LowerAlphaNum = /[a-z][a-z0-9_]*/
  BadName = Exception.new("Invalid pathname")

puts "--- Read yaml..."
puts "--- store ="
pp @store
  
  def self.make_root
    t = Topic.allocate
    t.name = "/"
    t.path = "/"
    t.parent = nil
    t.children = []
    t.id = Socrates::TopicStore.count += 1
    Topic.current = t
  end

# Root = @store["/"] || Socrates::TopicStore.add!("/", "")
  Root = (@store["/"] ||= Socrates::TopicStore.make_root)
puts "--- Defined Root..."
puts "--- store ="
pp @store
  
  def self.add(name, desc, parent=Socrates::Topic.current)
    raise BadName unless name =~ LowerAlphaNum || parent.nil?
puts "Creating: #{[name, desc, (parent.name rescue 'Root')].inspect}"
    topic = Topic.new(name, desc, parent)
    topic.id = Socrates::TopicStore.count += 1
    parent.children << topic unless parent.nil?
    @store[topic.path] = topic    
  end

  def self.add!(name, desc, parent=Socrates::Topic.current)
    topic = add(name, desc, parent)
    Topic.current = topic
  end

  def self.valid_path?(path)
    return true if path == "/" 
    return false if path[0] != "/"
    names = path[1..-1].split("/")
    return false if names.empty?
    names.each {|name| return false unless name =~ LowerAlphaNum }
    return true
  end

  def self.lookup(path)
    raise BadName unless valid_path?(path)
    @store[path]
  end

  def self.load(file="topics.yaml")
    @store = YAML.load(file)
  end

  def self.save(file="topics.yaml")
    File.open(file, "w") {|f| f.puts @store.to_yaml }
  end
end

###

class Socrates::DataStore
  def initialize
    @db = ::Sequel.connect("sqlite://socrates.db")
  end

  def method_missing(sym, *args, &block)
p [sym, args]
    @db.send(sym, *args, &block)
  end

  def add(table, obj)
    @db[table].insert(obj)
  end

  def lookup(table, id)
    @db[table][id]
  end

  def new_topic(name, desc)
    Socrates::Topic.add(name, desc)
  end

  def new_topic!(name, desc)
    Socrates::Topic.add!(name, desc)
  end

  def new_question(text, correct)
    topic = Socrates::Topic.current
    @db[:questions].insert(topic_id: topic.id, text: text, correct_answer: correct)
    # child will be nil - no inheritance
  end

  def get_questions(topic, num=10)
    ds = @db[:questions]
    if topic.children.any?
      array = topic.children.map {|t| t.id }
      ds = ds.filter(topic_id: array)
    else
      ds = ds.filter(topic_id: topic.id)
    end
    list = ds.to_a.sort_by { rand }
    list = list[0..num-1]
    list.map {|hash| Socrates::Question.new(hash[:text], hash[:correct_answer]) }
  end
end

