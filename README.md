#Sprinkle WebRTC deployment tasks

![Screencapture GIF](https://dl.dropboxusercontent.com/u/49541944/screenshots/out.gif)

This is a first stab at introducing low barrier to entry automation to deployment tasks and avoid the vicious manual configuration.

##What do you get?

* Simplicity: Push to target hosts over SSH from the comfort of your dev machine. No software installation required on target.
* Declarative format
* Idempotent scripts
* Basic dependency management.

##Requirements

* Ruby
* Sprinkle gem

##Installation
Easiest way to not mess up your system ruby that you care so much about is to use rvm

```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | bash -s stable --ruby
source /home/youruser/.rvm/scripts/rvm
rvm gemset create sprinkle
rvm use @sprinkle
gem install sprinkle
```
* Clone repo

```
git clone https://github.com/lfurrea/sprinkle-webrtc.git
cd sprinkle-webrtc
```
* Edit config.rb to suit your needs
* Edit deploy.rb and configure username for 'deploy user' and list of kamailio servers 


##Usage
Usage deploy-webrtc.rb /local/path/to/cert.pem /local/path/to/key.pem /local/path/to/certs/dir 
 
Requires EXACTLY three arguments  to get the server certificate, server key
 and certificate bundle, they all need to reside on the local filesystem

##Troubleshooting

* Passwordless sudo  works best but it should prompt for pass otherwise
* Read access to inspect the certificate and key are required

##TODO

* Use SSL to validate certificate before restarting kamailio
* Is there anyway to verify the key?
* Support for multiple SIP profiles on the FS server when enabling PRACK
