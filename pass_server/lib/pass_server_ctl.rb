#!/usr/bin/env ruby
#
#  pass_server_ctl
#  Pass Server reference implementation
#
#  Copyright (c) 2012 Apple, Inc. All rights reserved.
#

#!/usr/env ruby
require 'rubygems'
require 'sequel'
require 'sequel/extensions/pretty_table'
require 'open-uri'
require 'json'
require 'fileutils'
require 'optparse'
require 'securerandom'
require File.dirname(File.expand_path(__FILE__)) + '/apns.rb'



class ReferenceServerSetup
  attr_accessor :db, :db_file, :hostname, :port, :pass_type_identifier
  
  def initialize
    self.db_file =  File.dirname(File.expand_path(__FILE__)) + "/../data/pass_server.sqlite3"
    self.hostname = "tiefflieger.local"
    self.port = 4567
    self.pass_type_identifier = "pass.com.codekollektiv.balance"
  end
    
  def setup_hostname
    # json_ip = open('http://jsonip.com'){|f| JSON.parse(f.read)}
    # hostname = collect_user_input("Please enter the hostname or ip address for the server [%@]:", json_ip["ip"], "The hostname is set to %@")
    # self.hostname = hostname
    self.hostname = "tiefflieger.local"
  end
  
  def setup_webserver_port
    # default_port = 4567
    # port = collect_user_input("Please enter a port to use for the webserver [%@]:", default_port, "The webserver port it set to %@")
    # self.port = port
    
    self.port = 4567
  end
  
  def setup_pass_type_identifier    
    # self.pass_type_identifier = collect_user_input("Please enter the passTypeIdentifer associated with your certificate:", "", "The passTypeIdentifer is set to %@")
    self.pass_type_identifier = "pass.com.codekollektiv.balance"
  end
  
  def get_certificate_path
    certDirectory = File.dirname(File.expand_path(__FILE__)) + "/../Data/Certificate"
    certs = Dir.glob("#{certDirectory}/*.p12")
    if  certs.count ==0
      puts "Couldn't find a certificate at #{certDirectory}"
      puts "Exiting"
      Process.exit
    else
      certificate_path = certs[0]
    end
  end
  
  def setup_database
    # Create an empty database file
    if !File.exists?(self.db_file)
      File.open(self.db_file, "w"){}
    end
  end
  
  def open_database
    # Open the database
    self.db = Sequel.sqlite(self.db_file)
    puts "Loading the database file"
  end
  
  def create_users_table
    # Create the Users table
    if !self.db.table_exists?(:users)
      puts "Creating the users table"
      self.db.create_table :users do
        primary_key :id
        String :email
        String :name
        Float :account_balance
        DateTime :created_at
        DateTime :updated_at
      end
    end
  end

  def create_passes_table
    # Create the Passes table
    if !self.db.table_exists?(:passes)
      puts "Creating the passes table"
      self.db.create_table :passes do
        primary_key :id
        foreign_key :user_id, :users, :on_delete => :cascade, :on_update => :cascade
        String :serial_number
        String :authentication_token
        String :pass_type_id
        DateTime :created_at
        DateTime :updated_at
      end
    end
  end
  
  def create_registrations_table
    # Create the registrations table
    if !self.db.table_exists?(:registrations)
      puts "Creating the registrations table"
      self.db.create_table :registrations do
        primary_key :id
        String :uuid
        String :device_id
        String :push_token
        String :serial_number
        String :pass_type_id
        DateTime :created_at
        DateTime :updated_at
      end
    end
  end
  
  # def create_sample_pass
  #   passes = self.db[:passes]
  #   if passes.count < 1
  #     puts "Inserting a sample pass"
  #     add_pass("1", "30c4cb4ba863fa9d7687959d8fbc6f0c", self.pass_type_identifier)
  #   end
  # end
  
  def add_user(email, name, account_balance)
    users = self.db[:users]
    now = DateTime.now
    users.insert(:email => email, :name => name, :account_balance => account_balance, :created_at => now, :updated_at => now)
    puts "<#User email: #{email} name: #{name} account_balance: #{account_balance}>"
  end

  def delete_user(user_id)
    users = self.db[:users]
    users.filter(:id => user_id).delete
  end

  def add_pass_for_user(user_id)
    serial_number = SecureRandom.hex
    authentication_token = SecureRandom.hex
    add_pass(serial_number, authentication_token, "pass.com.codekollektiv.balance", user_id)
  end

  def add_pass(serial_number, authentication_token, pass_type_id, user_id)
    passes = self.db[:passes]
    now = DateTime.now
    passes.insert(:serial_number => serial_number, :authentication_token => authentication_token, :pass_type_id => pass_type_id, :user_id => user_id, :created_at => now, :updated_at => now)
    puts "<#Pass serial_number: #{serial_number} authentication_token: #{authentication_token} pass_type_id: #{pass_type_id} user_id: #{user_id}>"
  end
  
  def delete_pass(pass_id)
    passes = self.db[:passes]
    passes.filter(:id => pass_id).delete
  end
  
  def create_pass_data_for_pass(pass_id)
    passes_folder_path = File.dirname(File.expand_path(__FILE__)) + "/../data/passes"
    template_folder_path = passes_folder_path + "/template"
    target_folder_path = passes_folder_path + "/#{pass_id}"
    
    # Delete pass folder if it already exists
    if (Dir.exists?(target_folder_path))
      puts "Deleting existing pass data"
      FileUtils.remove_dir(target_folder_path)
    end

    # Copy pass files from template folder
    puts "Creating pass data from template"
    FileUtils.cp_r template_folder_path + "/.", target_folder_path

    # Load pass data from database
    pass = self.db[:passes].where[:id => pass_id]
    user = self.db[:users].where[:id => pass[:user_id]]

    # Modify the pass json
    puts "Updating pass data"
    json_file_path = target_folder_path + "/pass.json"
    pass_json = JSON.parse(File.read(json_file_path))
    pass_json["passTypeIdentifier"] = self.pass_type_identifier
    pass_json["serialNumber"] = pass[:serial_number]
    pass_json["authenticationToken"] = pass[:authentication_token]
    pass_json["webServiceURL"] = "http://#{self.hostname}:#{self.port}/"
    pass_json["barcode"]["message"] = pass[:serial_number]
    pass_json["storeCard"]["primaryFields"][0]["value"] = user[:account_balance]
    pass_json["storeCard"]["secondaryFields"][0]["value"] = user[:name]

    # Write out the updated JSON
    File.open(json_file_path, "w") do |f|
      f.write JSON.pretty_generate(pass_json)
    end
  end

  # def update_sample_pass_json
  #   # Read in the pass json
  #   json_file_path = File.dirname(File.expand_path(__FILE__)) + "/../data/passes/1/pass.json"
  #   pass_json = JSON.parse(File.read(json_file_path))
  #   pass_json["webServiceURL"] = "http://#{self.hostname}:#{self.port}/"
  #   pass_json["passTypeIdentifier"] = self.pass_type_identifier
    
  #   puts "Updating the pass' webServiceURL to #{pass_json["webServiceURL"]}"
    
  #   # Write out the updated JSON
  #   File.open(json_file_path, "w") do |f|
  #     f.write JSON.pretty_generate(pass_json)
  #   end
    
  # end
  
  
  private
  def collect_user_input(request_message, default_value, completion_message)
    puts request_message.gsub("%@", default_value.to_s)
    input = gets.chomp
    if input.nil? || input == ""
      output = default_value
    else
      output = input
    end
    puts completion_message.gsub("%@", output.to_s)
    puts "\n\n"
    return output
  end
  
end


options = {}
optparse = OptionParser.new do |opts|
  
  options[:add_user] = []
  opts.on('--add-user email,name,account_balance', Array, "Add a user to the database") do |u|
    options[:add_user] = u
  end

  options[:delete_user] = nil
  opts.on('--delete-user id', Integer, "Deletes a user from the database with a given row id") do |d|
    options[:delete_user] = d
  end

  options[:add_pass] = []
  opts.on('--add-pass user_id', Array, "Adds a pass for the given user id to the database") do |p|
    options[:add_pass] = p
  end

  options[:create_pass] = nil
  opts.on('--create-pass pass_id', Integer, "Creates the data on disk for the given pass id") do |p|
    options[:create_pass] = p
  end
  
  options[:delete_pass] = nil
  opts.on('--delete-pass id', Integer, "Deletes a pass from the database with a given row id") do |d|
    options[:delete_pass] = d
  end
  
  options[:setup] = false
  opts.on("--setup", "Setup the pass server") do |s|
    options[:setup] = s
  end
  
  options[:users] = false
  opts.on("--users", "List the users in the database") do |u|
    options[:users] = u
  end

  options[:passes] = false
  opts.on("--passes", "List the passes in the database") do |p|
    options[:passes] = p
  end
  
  options[:registrations] = false
  opts.on("--registrations", "List the registrations in the database") do |r|
    options[:registrations] = r
  end
  
  options[:push_notification] = false
  opts.on("--push", "Sends a push notification to registered devices, causing them to check for updated passes") do |n|
    options[:push_notification] = n
  end
  
  # options[:start_server] = false
  # opts.on("server", "Starts the webserver on port 4567") do |s|
  #   options[:start_server] = s
  # end
  
  opts.on('-h', '--help', 'Display this screen') do 
    puts opts
    exit
  end
  
end

optparse.parse!
if options[:setup]
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.setup_hostname
  reference_server_setup.setup_webserver_port
  reference_server_setup.get_certificate_path
  reference_server_setup.setup_pass_type_identifier
  reference_server_setup.setup_database
  reference_server_setup.open_database
  reference_server_setup.create_users_table
  reference_server_setup.create_passes_table
  reference_server_setup.create_registrations_table
  # reference_server_setup.create_sample_pass
  # reference_server_setup.update_sample_pass_json
  puts "Reference server setup complete."
end

if !options[:add_user].nil? && options[:add_user].length == 3
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.open_database
  reference_server_setup.add_user(options[:add_user][0], options[:add_user][1], options[:add_user][2])
  if reference_server_setup.db[:users].count > 0
    Sequel::PrettyTable.print(reference_server_setup.db[:users])
  else
    puts "No records to display."
  end
end

if !options[:delete_user].nil?
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.open_database
  reference_server_setup.delete_user(options[:delete_user])
  if reference_server_setup.db[:users].count > 0
    Sequel::PrettyTable.print(reference_server_setup.db[:users])
  else
    puts "No records to display."
  end
end

if !options[:add_pass].nil? && options[:add_pass].length == 1
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.open_database
  reference_server_setup.add_pass_for_user(options[:add_pass][0])
  if reference_server_setup.db[:passes].count > 0
    Sequel::PrettyTable.print(reference_server_setup.db[:passes])
  else
    puts "No records to display."
  end
end

if !options[:create_pass].nil?
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.open_database
  reference_server_setup.create_pass_data_for_pass(options[:create_pass])
end

if !options[:delete_pass].nil?
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.open_database
  reference_server_setup.delete_pass(options[:delete_pass])
  if reference_server_setup.db[:passes].count > 0
    Sequel::PrettyTable.print(reference_server_setup.db[:passes])
  else
    puts "No records to display."
  end
end

if options[:users]
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.open_database
  if reference_server_setup.db[:users].count > 0
    Sequel::PrettyTable.print(reference_server_setup.db[:users])
  else
    puts "No records to display."
  end
end

if options[:passes]
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.open_database
  if reference_server_setup.db[:passes].count > 0
    Sequel::PrettyTable.print(reference_server_setup.db[:passes])
  else
    puts "No records to display."
  end
end

if options[:registrations]
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.open_database
  if reference_server_setup.db[:registrations].count > 0
    Sequel::PrettyTable.print(reference_server_setup.db[:registrations])
  else
    puts "No records to display."
  end
end

if options[:push_notification]
  reference_server_setup = ReferenceServerSetup.new
  reference_server_setup.open_database
  APNS.instance.open_connection("production")
  puts "Opening connection to APNS."

  # Get the list of registered devices and send a push notification
  push_tokens = reference_server_setup.db[:registrations].collect{|r| r[:push_token]}.uniq
  push_tokens.each do |push_token|
    puts "Sending a notification to #{push_token}"
    APNS.instance.deliver(push_token, "{}")
  end

  APNS.instance.close_connection
  puts "APNS connection closed."
end

