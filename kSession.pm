package CGI::kSession;
$CGI::kSession::VERSION = '0.5.2';
use strict;

sub new {
    my ($c, %args) = @_;
    my $class = ref($c) || $c;
    $args{SID} = $args{id};
    bless \%args, $class;
}

sub start {
    my $cl = shift;
    if (!exists($cl->{lifetime})) { $cl->{lifetime} = 600; }
    if (!exists($cl->{path})) { $cl->{path} = "/var/tmp/"; }
    # ustawia nowy ID jesli nie jest zaden podany juz
    if ((!exists($cl->{SID})) || ((length($cl->{SID}) == 0))) { $cl->id($cl->newID()); }
    
    if (-e $cl->getfile()) { return 0; }
    # nowy plik sesji jesli takowy juz nie istnieje
    open(SF,">".$cl->getfile()); close(SF);
    $cl->check_sessions();
    return 1;
}

sub check_sessions {
    my $cl = shift;
    opendir(SD,$cl->{path});
    my @files = readdir(SD);
    shift @files;
    shift @files;
    foreach my $f (@files) {
	if (((stat($cl->{path}.$f))[9] + $cl->{lifetime}) < time()) { 
		unlink($cl->{path}.$f); 
		}
	}
    closedir(SD);
}

sub destroy {
    my $cl = shift;
    if (!$cl->have_id()) { return -1; }
    if (-e $cl->getfile()) { unlink($cl->getfile()); }
    undef $cl->{SID};
    if (defined($cl->{id}))  { undef $cl->{id}; }
    return 1;
}

#czy sesja o podanym id istnieje
sub exists {
    my ($cl,$id) = @_;
    if (!defined($id)) { return 0; }
    my $file = $cl->{path}.$cl->{$id};
    if (-e $file) { return 1; }
    return 0;
}

sub have_id {
    my $cl = shift;
    if (!exists($cl->{SID})) { return 0; }
    return 1;
}

sub save_path {
    my ($cl, $path) = @_;
    if (defined($path)) { $cl->{path} = $path }
    return $cl->{path};
}

sub id {
    my ($cl, $newid) = @_;
    if (!$cl->have_id()) { return -1; }
    if (defined($newid)) { $cl->{SID} = $newid; }
    return $cl->{SID};
}

sub getfile {
    my $cl = shift;
    return $cl->{path}.$cl->{SID};
}

sub is_registered {
    my ($cl,$name) = @_;
    if (!$cl->have_id()) { return -1; }
    if (-e $cl->getfile()) {
	open(SF,$cl->getfile);
	while (my $l = <SF>) {
	    my @line = split (/=/,$l);
	    if ($line[0] eq $name) { 
		close(SF); 
		return 1;
		}
	    }
	close(SF);
    }
    return 0;
}


sub register {
    my ($cl,$name) = @_;
    if (!$cl->have_id()) { return -1; }
    if ($cl->is_registered($name)) { return 0; }
    if (-e $cl->getfile()) {
	open(SF,">>".$cl->getfile());
	print SF $name."=\n";
	close(SF);
	return 1;
    }
    return 0;
}

sub unregister {
    my ($cl,$name) = @_;
    my $content = "";
    if (!$cl->have_id()) { return -1; }
    if (!$cl->is_registered($name)) { return 0; }
     open(SF,$cl->getfile());
     while (my $l = <SF>) { 
        $l =~ s/^$name=(.*?)\n//i;
        $content .= $l; 
	}
     close(SF);
    open(SF,">".$cl->getfile());
#	$content =~ s/$name=(.*?)\n//gis;
    print SF $content; 
    close(SF);
}

sub unset {
    my $cl = shift;
    open(SF,">".$cl->getfile());
    close(SF);
}

sub get {
    my ($cl,$name) = @_;
    if (!$cl->have_id()) { return -1; }
    if ($cl->is_registered($name)) {
	if (-e $cl->getfile()) {
	open(SF,$cl->getfile());
	while (my $l = <SF>) {
	    if ($l =~ /^$name=(.*?)\n/i) {
		close(SF); 
		return $1; 
		}
#	    my @line = split (/=/,$l);
#	    if ($line[0] eq $name) { 
#		close(SF); 
#		return $line[1]; 
#		}
	    }
	close(SF);
	} 
    } else { 
    return -1;
    };
}

sub set {
    my ($cl,$name,$value) = @_;
    if (!$cl->have_id()) { return -1; }
    if ($cl->is_registered($name)) {
	my $content = "";
	
	open(SF,$cl->getfile()); 
	while (my $l = <SF>) { 
    	    $l =~ s/^$name=(.*?)\n/$name=$value\n/gis;
	    $content .= $l; 
	    }
	close(SF);
#	$content =~ s/$name=(.*?)\n/$name=$value\n/gis;
	open(SF,">".$cl->getfile());
	print SF $content; 
	close(SF);
	return 1;
    }
    return 0;
}


sub newID {
    my $cl = shift;
    my $ary = "0123456789abcdefghijABCDEFGH";	# replace with the set of characters
    $cl->{SID} = "";
    my $arylen = length($ary);
    for my $i (0 .. 23) {
	my $idx = int(rand(time) % $arylen);
	my $dig = substr($ary, $idx, 1);
#	if ($i > 0) {
#	    if ($i % 8 == 0) { $cl->{SID} .= "-"; }
#	    elsif ($i % 4 == 0) {$cl->{SID} .= "_"; }
#	} 
	$cl->{SID} .= $dig;
    } $cl->{SID};
}

#############################

1;
__END__

=head1 NAME
CGI::kSession - sessions manager
    
=head1 DESCRIPTION

kSession.pm v 0.5.2 by Marcin Krzyzanowski <krzak at linux.net.pl> 
http://krzak.linux.net.pl/
License : GPL
    
You can use it everywhere you need sessions.
Use files to handle sessions.
Syntax is little bit similar to session as you known from php.


=head1 EXAMPLE

 use strict;
 use CGI;
 use CGI::kSession;

    my $cgi = new CGI;
    print $cgi->header;

    my $s = new CGI::kSession(lifetime=>10,path=>"/home/user/sessions/",id=>$cgi->param("SID"));
    $s->start();
    # $s->save_path('/home/user/sessions/');

    # registered "zmienna1"
    $s->register("zmienna1");
    $s->set("zmienna1","wartosc1");
    print $s->get("zmienna1"); #should print out "wartosc1"

    if ($s->is_registered("zmienna1")) {
	print "Is registered";
	} else {
	print "Not registered";
	}

    # unregistered "zmienna1"
    $s->unregister("zmienna1");
    $s->set("zmienna1","wartosc2");
    print $s->get("zmienna1"); #should print out -1
    
    $s->unset(); # unregister all variables
    $s->destroy(); # delete session with this ID

=cut
