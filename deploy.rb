# Change to suit your needs
set :user, 'lurrea'
role :kamailio, 'apps001.dfw.qa.gridmobile.com', 'apps002.dfw.qa.gridmobile.com'
role :freeswitch, 'apps001.dfw.qa.gridmobile.com'
ssh_options[:port] = 22223
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh/", "id_rsa")]

#Do not change below this line
set :run_method, :sudo
