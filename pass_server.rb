#
# File:       pass_server.rb
#
# Abstract:   Pass Server reference implementation
#
# Version:    1.0
#
# Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Inc. ("Apple")
#             in consideration of your agreement to the following terms, and your use,
#             installation, modification or redistribution of this Apple software
#             constitutes acceptance of these terms.  If you do not agree with these
#             terms, please do not use, install, modify or redistribute this Apple
#             software.
#
#             In consideration of your agreement to abide by the following terms, and
#             subject to these terms, Apple grants you a personal, non - exclusive
#             license, under Apple's copyrights in this original Apple software ( the
#             "Apple Software" ), to use, reproduce, modify and redistribute the Apple
#             Software, with or without modifications, in source and / or binary forms;
#             provided that if you redistribute the Apple Software in its entirety and
#             without modifications, you must retain this notice and the following text
#             and disclaimers in all such redistributions of the Apple Software. Neither
#             the name, trademarks, service marks or logos of Apple Inc. may be used to
#             endorse or promote products derived from the Apple Software without specific
#             prior written permission from Apple.  Except as expressly stated in this
#             notice, no other rights or licenses, express or implied, are granted by
#             Apple herein, including but not limited to any patent rights that may be
#             infringed by your derivative works or by other works in which the Apple
#             Software may be incorporated.
#
#             The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
#             WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
#             WARRANTIES OF NON - INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
#             PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION
#             ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
#
#             IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
#             CONSEQUENTIAL DAMAGES ( INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#             SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#             INTERRUPTION ) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION
#             AND / OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER
#             UNDER THEORY OF CONTRACT, TORT ( INCLUDING NEGLIGENCE ), STRICT LIABILITY OR
#             OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Copyright ( C ) 2012 Apple Inc. All Rights Reserved.
#
require 'sinatra/base'
require 'sequel'
require 'sqlite3'
require 'yaml'
require 'json'
require 'socket'
require 'sign_pass'
require 'securerandom'
require File.dirname(File.expand_path(__FILE__)) + '/lib/apns.rb'

class PassServer < Sinatra::Base
  attr_accessor :certificate_password
  attr_accessor :hostname, :port, :pass_type_identifier

  configure do
    mime_type :pkpass, 'application/vnd.apple.pkpass'
  end
  
  def setup_hostname
    self.hostname = "tiefflieger.local"
  end
  
  def setup_webserver_port
    self.port = 4567
  end
  
  def setup_pass_type_identifier    
    self.pass_type_identifier = "pass.com.codekollektiv.balance"
  end
  
  def get_certificate_path
    certDirectory = File.dirname(File.expand_path(__FILE__)) + "/data/Certificate"
    certs = Dir.glob("#{certDirectory}/*.p12")
    if  certs.count ==0
      puts "Couldn't find a certificate at #{certDirectory}"
      puts "Exiting"
      Process.exit
    else
      certificate_path = certs[0]
    end
  end

  before do
    setup_hostname
    setup_webserver_port
    setup_pass_type_identifier

    # Load in the pass data before each request
    @db = Sequel.sqlite("data/pass_server.sqlite3")
    @passes ||= @db[:passes]
    @registrations ||= @db[:registrations]
  end
  

  def add_pass_for_user(user_id)
    serial_number = SecureRandom.hex
    authentication_token = SecureRandom.hex
    add_pass(serial_number, authentication_token, "pass.com.codekollektiv.balance", user_id)
  end

  def add_pass(serial_number, authentication_token, pass_type_id, user_id)
    passes = @db[:passes]
    now = DateTime.now
    passes.insert(:serial_number => serial_number, :authentication_token => authentication_token, :pass_type_id => pass_type_id, :user_id => user_id, :created_at => now, :updated_at => now)
    puts "<#Pass serial_number: #{serial_number} authentication_token: #{authentication_token} pass_type_id: #{pass_type_id} user_id: #{user_id}>"
  end


  
  # Registration
  # register a device to receive push notifications for a pass
  #
  # POST /v1/devices/<deviceID>/registrations/<typeID>/<serial#>
  # Header: Authorization: ApplePass <authenticationToken>
  # JSON payload: { "pushToken" : <push token, which the server needs to send push notifications to this device> }
  #
  # Params definition
  # :device_id      - the device's identifier
  # :pass_type_id   - the bundle identifier for a class of passes, sometimes refered to as the pass topic, e.g. pass.com.apple.backtoschoolgift, registered with WWDR
  # :serial_number  - the pass' serial number
  # :pushToken      - the value needed for Apple Push Notification service
  #
  # server action: if the authentication token is correct, associate the given push token and device identifier with this pass
  # server response:
  # --> if registration succeeded: 201
  # --> if this serial number was already registered for this device: 304
  # --> if not authorized: 401
  
  post '/v1/devices/:device_id/registrations/:pass_type_id/:serial_number' do
    puts "Handling registration request..."
    # validate that the request is authorized to deal with the pass referenced
    puts "#<RegistrationRequest device_id: #{params[:device_id]}, pass_type_id: #{params[:pass_type_id]}, serial_number: #{params[:serial_number]}, authentication_token: #{authentication_token}, push_token: #{push_token}>"
    if @passes.where(:serial_number => params[:serial_number]).where(:authentication_token => authentication_token).first
      
      puts '[ ok ] Pass and authentication token match.'
      
      # Validate that the device has not previously registered
      # Note: this is done with a composite key that is combination of the device_id and the pass serial_number
      uuid = params[:device_id] + "-" + params[:serial_number]
      if @registrations.where(:uuid => uuid).count < 1
        
        puts '[ ok ] New registration, creating.'

        # No registration found, lets add the device
        @registrations.insert(:uuid => uuid, :device_id => params[:device_id], :pass_type_id => params[:pass_type_id], :push_token => push_token, :serial_number => params[:serial_number])
        
        # Return a 201 CREATED status
        status 201
      else
        # The device has already registered for updates on this pass
        # Acknowledge the request with a 200 OK response
        puts '[ ok ] Device is already registered.'
        status 200
      end
      
    else
      # The device did not statisfy the authentication requirements
      # Return a 401 NOT AUTHORIZED response
      puts '[ fail ] Registration request is not authorized.'
      status 401
    end

  end
   
   
  # Updatable passes
  #
  # get all serial #s associated with a device for passes that need an update
  # Optionally with a query limiter to scope the last update since
  # 
  # GET /v1/devices/<deviceID>/registrations/<typeID>
  # GET /v1/devices/<deviceID>/registrations/<typeID>?passesUpdatedSince=<tag>
  #
  # server action: figure out which passes associated with this device have been modified since the supplied tag (if no tag provided, all associated serial #s)
  # server response:
  # --> if there are matching passes: 200, with JSON payload: { "lastUpdated" : <new tag>, "serialNumbers" : [ <array of serial #s> ] }
  # --> if there are no matching passes: 204
  # --> if unknown device identifier: 404
  #
  #
  get '/v1/devices/:device_id/registrations/:pass_type_id?' do
    puts "Handling updates request..."
    # Check first that the device has registered with the service
    if @registrations.where(:device_id => params[:device_id]).count > 0
      
      # The device is registered with the service
      puts '[ ok ] Device registration found.'
      
      # Find the registrations for the device
      registered_serial_numbers = @registrations.where(:device_id => params[:device_id], :pass_type_id => params[:pass_type_id]).collect{|r| r[:serial_number]}
      
      # The passesUpdatedSince param is optional for scoping the update query
      if params[:passesUpdatedSince] && params[:passesUpdatedSince] != ""
        updated_since = DateTime.strptime(params[:passesUpdatedSince], '%s')
        registered_passes = @passes.where(:serial_number => registered_serial_numbers).filter('updated_at IS NULL OR updated_at >= ?', updated_since)
      else
        registered_passes = @passes.where(:serial_number => registered_serial_numbers)
      end
      
      # Are there passes that this device should recieve updates for?
      if registered_passes.count > 0
        # Found passes that could be updated for this device
        puts '[ ok ] Found passes that could be updated for this device.'
        
        # Build the response object
        update_time = DateTime.now.strftime('%s')
        updatable_passes_payload = {:lastUpdated => update_time}
        updatable_passes_payload[:serialNumbers] = registered_passes.collect{|rp| rp[:serial_number]}
        
        updatable_passes_payload.to_json
        
      else
        puts '[ ok ] No passes found that could be updated for this device.'
        status 204

      end
      
    else
      # This device is not currently registered with the service
      puts '[ fail ] Device is not registered.'
      status 404
    end
  end
  
  # Unregister
  #
  # unregister a device to receive push notifications for a pass
  # 
  # DELETE /v1/devices/<deviceID>/registrations/<passTypeID>/<serial#>
  # Header: Authorization: ApplePass <authenticationToken>
  #
  # server action: if the authentication token is correct, disassociate the device from this pass
  # server response:
  # --> if disassociation succeeded: 200
  # --> if not authorized: 401
  delete "/v1/devices/:device_id/registrations/:pass_type_id/:serial_number" do 
    puts "Handling unregistration request..."
    if @passes.where(:serial_number => params[:serial_number], :authentication_token => authentication_token).first
      puts '[ ok ] Pass and authentication token match.'
      
      # Validate that the device has previously registered
      # Note: this is done with a composite key that is combination of the device_id and the pass serial_number
      uuid = params[:device_id] + "-" + params[:serial_number]
      if @registrations.where(:uuid => uuid).count > 0
        @registrations.where(:uuid => uuid).delete
        status 200
      else
        puts '[ fail ] Registration does not exist.'
        status 401
      end
    
    else
      # Not authorized
      puts '[ fail ] Not authorized.'
      status 401
    end
    
  end
  
  
  # Pass delivery
  #
  # GET /v1/passes/<typeID>/<serial#>
  # Header: Authorization: ApplePass <authenticationToken>
  #
  # server response:
  # --> if auth token is correct: 200, with pass data payload
  # --> if auth token is incorrect: 401
  #
  get '/v1/passes/:pass_type_id/:serial_number' do
    puts "Handling pass delivery request..."
    if @passes.where(:serial_number => params[:serial_number]).where(:pass_type_id => params[:pass_type_id]).where(:authentication_token => authentication_token).first
      puts '[ ok ] Pass and authentication token match.'
      
      # Load pass data from database
      pass = @db[:passes].where[:serial_number => params[:serial_number]]
      user = @db[:users].where[:id => pass[:user_id]]
      pass_id = pass[:id]

      passes_folder_path = File.dirname(File.expand_path(__FILE__)) + "/data/passes"
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

      # Prepare for pass signing
      pass_folder_path = target_folder_path
      pass_signing_certificate_path = get_certificate_path
      pass_output_path = passes_folder_path + "/#{pass_id}.pkpass"
      
      # Remove the old pass if it exists
      if File.exists?(pass_output_path)
        File.delete(pass_output_path)
      end
      
      # Generate and sign the new pass
      pass_signer = SignPass.new(pass_folder_path, pass_signing_certificate_path, settings.certificate_password, pass_output_path)
      pass_signer.sign_pass!
      
      # Send the pass file
      puts '[ ok ] Sending pass file.'
      send_file(pass_output_path, :type => :pkpass)
    else
      puts '[ fail ] Not authorized.'
      status 401
    end
  end
  
  
  def push_update_for_pass(pass_id)
    APNS.instance.open_connection("production")
    puts "Opening connection to APNS."

    # Get the list of registered devices and send a push notification
    pass = @db[:passes].where(:id => pass_id).first
    push_tokens = @db[:registrations].where(:serial_number => pass[:serial_number]).collect{|r| r[:push_token]}.uniq
    push_tokens.each do |push_token|
      puts "Sending a notification to #{push_token}"
      APNS.instance.deliver(push_token, "{}")
    end

    APNS.instance.close_connection
    puts "APNS connection closed."
  end

  # Logging/Debugging from the device
  #
  # log an error or unexpected server behavior, to help with server debugging
  # POST /v1/log
  # JSON payload: { "description" : <human-readable description of error> }
  #
  # server response: 200
  #
  post "/v1/log" do
    if request && request.body
      request.body.rewind
      json_body = JSON.parse(request.body.read)
      File.open(File.dirname(File.expand_path(__FILE__)) + "/log/devices.log", "a") do |f|
        f.write "[#{Time.now}] #{json_body["description"]}\n"
      end
    end
    status 200
      
  end
  
  
  
  ################
  # FOR DEVELOPMENT PURPOSES ONLY
  # This endpoint is to allow developers to download a pass.
  # 
  # NOTE: This endpoint is not part of the offical API and does not implement
  # authentication/authorization controls and should only be used for development.
  # Please protect your user's data.
  #
  
  get "/users" do
    @users = @db[:users].order(:name).all
    erb :'users/index'
  end

  get "/users/new" do
    erb :'users/new'
  end

  post "/users" do
    @users = @db[:users]
    now = DateTime.now
    params[:user][:created_at] = now
    params[:user][:updated_at] = now
    new_user_id = @users.insert(params[:user])
    add_pass_for_user(new_user_id)
    redirect "/users"
  end

  get "/users/:user_id" do
    @user = @db[:users].where(:id => params[:user_id]).first
    erb :'users/show'
  end
  
  get "/users/:user_id/edit" do
    @user = @db[:users].where(:id => params[:user_id]).first
    erb :'users/edit'
  end

  put "/users/:user_id" do
    user = @db[:users].where(:id => params[:user_id])
    now = DateTime.now
    params[:user][:updated_at] = now
    user.update(params[:user])

    # Also update updated_at field of user's pass
    pass = @db[:passes].where(:user_id => params[:user_id])
    pass.update(:updated_at => now)

    # Send push notification
    push_update_for_pass(pass.first[:id])

    redirect "/users"
  end

  delete "/users/:user_id" do
    @db[:users].where(:id => params[:user_id]).delete
    redirect "/users"
  end

  get "/users/:user_id/pass.pkpass" do
    # Load pass data from database
    user = @db[:users].where[:id => params[:user_id]]
    pass = @db[:passes].where[:user_id => user[:id]]
    pass_id = pass[:id]

    passes_folder_path = File.dirname(File.expand_path(__FILE__)) + "/data/passes"
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

    # Prepare for pass signing
    pass_folder_path = target_folder_path
    pass_signing_certificate_path = get_certificate_path
    pass_output_path = passes_folder_path + "/#{pass_id}.pkpass"
    
    # Remove the old pass if it exists
    if File.exists?(pass_output_path)
      File.delete(pass_output_path)
    end
    
    # Generate and sign the new pass
    pass_signer = SignPass.new(pass_folder_path, pass_signing_certificate_path, settings.certificate_password, pass_output_path)
    pass_signer.sign_pass!
    
    # Send the pass file
    send_file(pass_output_path, :type => :pkpass)
  end
  
  ###
  # End of development only endpoint.
  ###############
  

  private
  
  def get_certificate_path
    certDirectory = File.dirname(File.expand_path(__FILE__)) + "/data/Certificate"
    certs = Dir.glob("#{certDirectory}/*.p12")
    if  certs.count ==0
	puts "Couldn't find a certificate at #{certDirectory}"
        puts "Exiting"
        Process.exit
    else
        certificate_path = certs[0]
    end
  end

  # Convenience method for parsing the authorization token header
  def authentication_token
    if env && env['HTTP_AUTHORIZATION']
      env['HTTP_AUTHORIZATION'].split(" ").last
    end
  end
  
  # Convenience method for parsing the pushToken out of a JSON POST body
  def push_token
    if request && request.body
      request.body.rewind
      json_body = JSON.parse(request.body.read)
      if json_body['pushToken']
        json_body['pushToken']
      end
    end
  end
end















