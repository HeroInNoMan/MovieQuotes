
use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = 'beta';
%IRSSI = (
    authors     => 'Hero In No Man',
    contact     => 'hero.in.no.man@gmail.com',
    name        => 'Movie quotes',
    description => 'This script prints random movie quotations which can be added by users' .
    license     => 'Public Domain',
    );

my @movies = (); # an array which will contain the file/movie names (each file stands for a movie).
my $channel; # the channel in which the script is 'running'.
my $directory; # the directory where the quote files are stored.
my $myNick = "HINM"; # the script's user nickname (to avoid annoying loops when present multiple times on $channel).
my @forbidden = ('list', 'help', 'random', 'add'); # words which are forbidden to use for new file names.
my $cooldown = 2; # The duration in seconds you have to wait between two calls to the script (avoids flooding).
my $timer = 0; # a timer to be used for calculating the cooldown time.
my $bottag = "[quotes]"; # a tag to avoid confusion between what is said by moviequotes and what is freely typed.


# Get all public messages and filter only the ones written on $channel.
# Also filter with a timer to avoid flooding.
# And do not take into account messages written by $my_nick.
sub public_quote {
    my ($server, $msg, $nick, $address, $target) = @_;
    if($target eq "$channel" && $nick ne "$myNick"){
	if(time > $timer){
	    proceed($server, $msg, $nick);
	    $timer = (time + $cooldown);
	}
    }
}

# Call the actions of the script manually.
sub cmd_quote {
    my ($data, $server, $witem) = @_;
    if(!$data){
      Irssi:print("%G$bottag No parameter given");
    } else {
	$server->command("MSG $channel !$data");
	proceed($server, "!$data", $myNick);
    }
}

# Depending on the command, call the right function.
sub proceed {
    my ($server, $text, $nick) = @_;
    my ($arg0, $movie, $quote) = split(' ', $text, 3);
    my $cmd = $arg0;
    if($arg0 =~ /^!\w+/) {
	$cmd = substr($arg0, 1, length($arg0)); 
	if($cmd eq "list" || $cmd eq "help") {
	    list_commands($server, $nick);
	} elsif($cmd eq "count" && $movie) {
	    count_quotes($server, $movie);
	} elsif($cmd eq "random") {
	    $movie = @movies[int(rand(scalar(@movies)))];
	    quote($server, $movie);
	} elsif($cmd eq "add" && $movie && $quote) {
	    add_quote($server, $movie, $quote);
	}else{
	    quote($server, $cmd);
	}    
    }
}

# Sends the number of quotes (file lines) within the specified file, if it exists.
sub count_quotes {
    my ($server, $movie) = @_;
    if(is_movie($movie)){
	open FILE, "$directory/$movie", or die $!;
	my @lines = <FILE>;
	my $number = scalar(@lines);
	if($number == 0){
	    $server->command("MSG $channel $bottag There are no quotes for $movie.");
	}elsif($number == 1){
	    $server->command("MSG $channel $bottag There is $number quote for $movie.");
	} else {
	    $server->command("MSG $channel $bottag There are $number quotes for $movie.");
	}
    }
}    

sub quote {
    my ($server, $movie) = @_;
    if(is_movie($movie)){
	open FILE, "$directory/$movie", or die $!;
	my @lines = <FILE>;
	my $quote = @lines[int(rand(scalar(@lines)))];
	$server->command("MSG $channel $bottag $quote");
    }
}

sub add_quote {
    my ($server, $movie, $quote) = @_;
# let's prevent malicious scripting inside user-added quotes:
    if( $movie =~ /\W/) {
	$server->command("MSG $channel $bottag Movie name must not contain non-word characters.");
    }
    if($quote =~ /[\\\/|*]/){
	$server->command("MSG $channel $bottag No commands in movie names or quotes ;)");
    } else {
	if(!is_forbidden($movie)){
	    if(!is_movie($movie)){
		push(@movies, $movie);
		$server->command("MSG $channel $bottag File added!");
	    }
	    open FILE, ">>$directory/$movie", or die $!;
	    print FILE "$quote\n";
	    close(FILE);
	    $server->command("MSG $channel $bottag Quote added!");
	}
    }
}

sub list_commands {
    my ($server, $nick) = @_;
    $server->command("MSG $nick $bottag List of available commands:");
    $server->command("MSG $nick $bottag !help");
    $server->command("MSG $nick $bottag !list");
    $server->command("MSG $nick $bottag !count <movie>");
    $server->command("MSG $nick $bottag !random");
    $server->command("MSG $nick $bottag !add <movie> <quote>");
    for(@movies){
	$server->command("MSG $nick $bottag !$_");
    }
}   

sub is_movie {
    my $string = $_[0];
    for(@movies){
	if($string eq $_){
	    return 1;
	}
    }
    return 0;
}

sub is_forbidden {
    my $string = $_[0];
    for(@forbidden){
	if($string eq $_){
	    return 1;
	}
    }
    return 0;
}

sub load_first {
    my @elements = `ls -1 $directory`;
    for(@elements) {
	if($_ =~ /[><~.\\\/*|]/) {
	} else {
	    chomp($_);
	    push(@movies, $_);
	}
    }
    my $size = scalar(@movies);
  Irssi:print("%G$bottag $size movies loaded.");
}

load_first();

Irssi::signal_add("message public", "public_quote");
Irssi::command_bind("moviequote", "cmd_quote");
