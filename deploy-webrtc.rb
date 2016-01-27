#!/usr/bin/env sprinkle -c -s
#/ Usage deploy-webrtc.rb /local/path/to/cert.pem /local/path/to/key.pem /local/path/to/certs/dir 
#/
#/ Test certificates:
#/ https://dl.dropboxusercontent.com/u/49541944/cert.pem
#/ https://dl.dropboxusercontent.com/u/49541944/key.pem
#/
#/ Requires three arguments: server certificate file, server key file, path to certificate directory
#/ Assumes the certificate chain resides in the same folder as server certificate and key
#/ Verify deployment after kamailio restart
#/ openssl s_client -showcerts -connect A.B.C.D:8443 -no_ssl2 -bugs

$stderr.sync = true
require 'open-uri'
require_relative 'config'

file = __FILE__
local_certs_dir = ""
bundle_file = 'certs/bundle.pem'

if File.exist?(bundle_file) then
  File.truncate(bundle_file, 0)
end

case ARGV.empty? || ARGV.length != 2
when false
  begin
    local_cert_file = open("certs/cert.pem", 'w')
    local_key_file = open("certs/key.pem", 'w')
    local_cert_chain = open("certs/bundle.pem", 'w')
  rescue
    raise "error opening temporary file #{$!}"
  end

  local_file = local_cert_file
  
  begin
    ARGV.each do |f|
      open(f) { |remote_file_obj|
        remote_file_obj.each_line do |line|
          if remote_file_obj.lineno == 1 and line =~ /^-----BEGIN CERTIFICATE-----/
            local_file = local_cert_file
          elsif remote_file_obj.lineno == 1 and line =~ /^-----BEGIN.*PRIVATE KEY-----/
            local_file = local_key_file
          elsif remote_file_obj.lineno == 1
            raise "Provided file does not seem to be a valid certificate or key {$!}"
          end
          local_file << line
        end
      }
    end
  rescue
    raise "error opening remote file to download #{$!}"
  end
  
  local_cert_file.close
  local_key_file.close
  local_certs_dir = File.dirname(ARGV.first)

  Dir.glob("#{local_certs_dir}/*.crt") do |cert|
    data = File.read(cert)
    local_cert_chain.write(data)
  end

  local_cert_chain.close
  
when true
  exec "grep ^#/<'#{file}'|cut -c4-"
end

package :backup_etc_kazoo do
  runner "test -d /etc/kazoo && sudo tar -zcvf kazoo-config." + Time.now.to_i.to_s + ".tar.gz /etc/kazoo", :sudo => true do
    pre :install, 'echo Cowardly backing up /etc/kazoo... This will always run!'
  end
end

package :backup_server_certificate do
  certificate_file = "#{CERTS_FOLDER}/cert.pem"
  runner "test -f #{certificate_file} && sudo cp #{certificate_file}{,-old." + Time.now.to_i.to_s + ".pem}; echo done", :sudo => true do
    pre :install, 'echo Cowardly backing up server certificate... This will always run!'
  end
end

#Always backup and keep original if it exists
package :backup_server_key do
  key_file = "#{CERTS_FOLDER}/key.pem" 
  runner "test -f #{key_file} && sudo cp #{key_file}{,-old." + Time.now.to_i.to_s + ".pem}; echo done", :sudo => true do
    pre :install, 'echo Cowardly backing up server key... This will always run!'
  end
end

#Always backup and keep original if it exists
package :backup_server_certificate_chain do
  ca_list_file = "#{CERTS_FOLDER}/ca_list.pem" 
  runner "test -f #{ca_list_file} && sudo cp #{ca_list_file}{,-old." + Time.now.to_i.to_s + ".pem}; echo done", :sudo => true do
    pre :install, 'echo Cowardly backing up server cert chain... This will always run!'
  end
end

package :maybe_create_certs_folder do
  runner "test ! -d #{CERTS_FOLDER} && sudo mkdir -p #{CERTS_FOLDER}; echo done", :sudo => true do
    post :install, "chown root:root #{CERTS_FOLDER}"
  end
end

package :deploy_server_certificate do
  requires :backup_server_certificate
  requires :maybe_create_certs_folder
  certificate_file = "#{CERTS_FOLDER}/cert.pem"

  file certificate_file, :content => File.read('certs/cert.pem'), :sudo => true do
    pre :install, 'echo Deploying server certificate ...'
    post :install, "chmod 644 #{certificate_file}"
  end

  verify do
    matches_local 'certs/cert.pem', "#{CERTS_FOLDER}/cert.pem"
  end
end

package :deploy_server_key do
  requires :backup_server_key
  requires :maybe_create_certs_folder
  key_file = "#{CERTS_FOLDER}/key.pem"

  file key_file, :content => File.read('certs/key.pem'), :sudo => true do
    pre :install, 'echo Deploying server key ...'
    post :install, "chmod 644 #{key_file}"
  end

  verify do
    matches_local 'certs/key.pem', "#{CERTS_FOLDER}/key.pem"
  end
end

package :deploy_certificate_chain do
  requires :backup_server_certificate_chain
  requires :maybe_create_certs_folder
  ca_list_file = "#{CERTS_FOLDER}/ca_list.pem"

  file ca_list_file, :content => File.read('certs/bundle.pem'), :sudo => true do
    pre :install, 'echo Deploying certificate chain ...'
    post :install, "chmod 644 #{ca_list_file}"
  end

  verify do
    matches_local 'certs/bundle.pem', "#{CERTS_FOLDER}/ca_list.pem"
  end
end

package :configure_websockets_domain do
  replace_text 'MY_WEBSOCKET_DOMAIN!.*!', "MY_WEBSOCKET_DOMAIN!#{WEBSOCKETS_DOMAIN}!", '/etc/kazoo/kamailio/local.cfg', :sudo => true

  verify do
    file_contains '/etc/kazoo/kamailio/local.cfg', "MY_WEBSOCKET_DOMAIN!#{WEBSOCKETS_DOMAIN}!"
  end
end

package :maybe_change_ws_port do
  requires :maybe_change_tcp_ws_port
  requires :maybe_change_udp_ws_port

  verify do
    file_contains '/etc/kazoo/kamailio/local.cfg', "TCP_WS!tcp:MY_IP_ADDRESS:#{WS_PORT}!"
    file_contains '/etc/kazoo/kamailio/local.cfg', "UDP_WS_SIP!udp:MY_IP_ADDRESS:#{WS_PORT}!"
  end
end

package :maybe_change_tcp_ws_port do
  replace_text 'TCP_WS!tcp:MY_IP_ADDRESS:.*!', "TCP_WS!tcp:MY_IP_ADDRESS:#{WS_PORT}!", '/etc/kazoo/kamailio/local.cfg', :sudo => true

  verify do
    file_contains '/etc/kazoo/kamailio/local.cfg', "TCP_WS!tcp:MY_IP_ADDRESS:#{WS_PORT}!"
  end
end

package :maybe_change_udp_ws_port do
  replace_text 'UDP_WS_SIP!udp:MY_IP_ADDRESS:.*!', "UDP_WS_SIP!udp:MY_IP_ADDRESS:#{WS_PORT}!", '/etc/kazoo/kamailio/local.cfg', :sudo => true
  
  verify do
    file_contains '/etc/kazoo/kamailio/local.cfg', "UDP_WS_SIP!udp:MY_IP_ADDRESS:#{WS_PORT}!"
  end
end

package :maybe_change_wss_port do
  requires :maybe_change_tcp_wss_port
  requires :maybe_change_udp_wss_port

  verify do
    file_contains '/etc/kazoo/kamailio/local.cfg', "TLS_WSS!tls:MY_IP_ADDRESS:#{WSS_PORT}!"
    file_contains '/etc/kazoo/kamailio/local.cfg', "UDP_WSS_SIP!udp:MY_IP_ADDRESS:#{WSS_PORT}!"
  end
end

package :maybe_change_tcp_wss_port do
  replace_text 'TLS_WSS!tls:MY_IP_ADDRESS:.*!', "TLS_WSS!tls:MY_IP_ADDRESS:#{WSS_PORT}!", '/etc/kazoo/kamailio/local.cfg', :sudo => true
  
  verify do
    file_contains '/etc/kazoo/kamailio/local.cfg', "TLS_WSS!tls:MY_IP_ADDRESS:#{WSS_PORT}!"
  end
end

package :maybe_change_udp_wss_port do
  replace_text 'UDP_WSS_SIP!udp:MY_IP_ADDRESS:.*!', "UDP_WSS_SIP!udp:MY_IP_ADDRESS:#{WSS_PORT}!", '/etc/kazoo/kamailio/local.cfg', :sudo => true
  
  verify do
    file_contains '/etc/kazoo/kamailio/local.cfg', "UDP_WSS_SIP!udp:MY_IP_ADDRESS:#{WSS_PORT}!"
  end
end

package :enable_websockets_role do
  requires :configure_websockets_domain
  replace_text '# # #!trydef WEBSOCKETS-ROLE', '#!trydef WEBSOCKETS-ROLE', '/etc/kazoo/kamailio/local.cfg', :sudo => true

  verify do
    file_contains '/etc/kazoo/kamailio/local.cfg', '^#!trydef WEBSOCKETS-ROLE'
  end
end

package :configure_certificate_key_paths do
  @certs_folder = CERTS_FOLDER
#  template_search_path File.dirname(__FILE__)
  file '/etc/kazoo/kamailio/tls.cfg', :contents => render("files/kamailio/tls.conf"), :sudo => true
end

package :enable_tls_role do
  requires :deploy_server_certificate
  requires :deploy_server_key
  requires :configure_certificate_key_paths
  replace_text '# # #!trydef TLS-ROLE', '#!trydef TLS-ROLE', '/etc/kazoo/kamailio/local.cfg', :sudo => true

  verify do
    file_contains '/etc/kazoo/kamailio/local.cfg', '^#!trydef TLS-ROLE' 
  end
end

package :enable_prack do
  replace_text '"enable-100rel" value="false"', '"enable-100rel" value="true"', '/etc/kazoo/freeswitch/sip_profiles/sipinterface_1.xml', :sudo => true

  verify {file_contains '/etc/kazoo/freeswitch/sip_profiles/sipinterface_1.xml', '"enable-100rel" value="true"' }
end

policy :prack, :roles => :freeswitch do
  requires :enable_prack
end

policy :webrtc, :roles => [:kamailio] do
  requires :backup_etc_kazoo
  requires :backup_server_certificate
  requires :backup_server_key
  requires :maybe_create_certs_folder
  requires :deploy_server_certificate
  requires :deploy_server_key
  requires :deploy_certificate_chain
  requires :configure_websockets_domain
  requires :maybe_change_ws_port
  requires :maybe_change_wss_port
  requires :enable_websockets_role
  requires :configure_certificate_key_paths
  requires :enable_tls_role
end

deployment do
  delivery :capistrano do
    begin
      recipes 'Capfile'
    rescue LoadError
      recipes 'deploy'
    end    
  end
end
