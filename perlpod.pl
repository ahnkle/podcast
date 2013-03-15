#!/usr/bin/perl
use Storable qw ( store retrieve );
use LWP::Simple qw( get );
use strict;
use Getopt::Long;

use constant {
  VERBOSE_LVL0 => 0,
  VERBOSE_LVL1 => 1,
  VERBOSE_LVL2 => 2,
  VERBOSE_LVL3 => 3,
  VERBOSE_LVL4 => 4,
};

my $feeds_list = ".feeds";
my $basedir = "podcasts";
my $urls = [];
my $ver = "v0.2";
my $verbose=0;
my $noget=0;

my $result = GetOptions(
    'noget+' => \$noget,
    'verbose|v+' => \$verbose
    );

sub feed_read($)
{
  my ( $rss_url ) = @_;
  print "\n=====================\n" if ($verbose > VERBOSE_LVL1);
  print "\n--> $rss_url\n" if ($verbose > VERBOSE_LVL2);

  my $rss = get ( $rss_url );
  die "failed to get $rss_url" unless defined $rss;

  $rss =~ s/[\r\n]//g;
  my $channel_title = parse_channel_title( $rss );
  while( $rss =~ /(\<item\>.*?\<\/item\>)/sg )
  {
    my $item = $1;
    print "....Found item\n" if ($verbose);
		print "$item\n" if ($verbose > VERBOSE_LVL2);
    my $title;
    if( $item =~ /\<title\>(.*?)\<\/title\>/i ) { 
        $title = $1; 
        print "....Found title: $title\n" if ($verbose > VERBOSE_LVL1); 
    }

    if( $item =~ /(\<enclosure.*?\>)/ )
    {
      my $enc = $1;
      if ( $enc =~ /url=[\"|\'](.*?)[\"|\']/i )
      {
          my $url = $1;
          print "....Found url $url" if ($verbose > VERBOSE_LVL1);
          my $filename = parse_filename( $1 );
          push @$urls , {
              url => $url, 
              filename => $filename,
              title => $title,
              channel => $channel_title
          };

          if ($channel_title =~ /^.*[\[\>\!]([^\[\]\>]+)/ ) {
              print "\n....fixed channel title: $1\n" if ($verbose > VERBOSE_LVL1);
              $channel_title = $1;
          }

          if ($noget == 0) {
              download_cast( $url, $filename, $channel_title ); 
          }
          else {
              print "\nskipping download ($url, $filename, $channel_title)\n";
          }
      }
    }
  }
  return $rss;
}

sub parse_channel_title($)
{
  my ($feed) =@_;
  my $chan_title;
#  if($feed =~ /\<channel\>(.*?)\<\/channel\>/) {
#	print ">>>$1<<<\n";
#    $channel = $1;
    if( $feed =~ /\<title\>(.*?)\<\/title\>/i ) {
      $chan_title = $1;
    }
#  }
  
  $chan_title;
}

sub parse_filename($)
{
  my ($filename) = @_;
  $filename =~ s/\?.*$//;
  $filename =~ s/^.*\///;
  return $filename;
}

sub read_feedlist($) {
  my ($filename) = @_;
  open FEEDLIST, "$filename" || die "could not open '$filename'";
  while( my $feed = <FEEDLIST> ) {
    chomp( $feed );
    feed_read ($feed) unless ( $feed =~ /^#/ )
#    { 
#      print "--> ($feed)\n";
#      feed_read( $feed );
#    }
  }
  close FEEDLIST;
}

sub download_cast($$$) 
{
    my ($url, $filename, $channel) =@_;

    my $dir = $basedir."/".$channel;
    my $fullpath = $dir."/".$filename;
  
    # Check if fill already exists
    if( -f $fullpath )
    {
	print "  - ($filename)\n" if ($verbose > VERBOSE_LVL0);
    }
    else
    {
	print "  + $filename ($url)...\n";
  
	my $data = get $url;

	mkdir( $basedir );
	mkdir( $dir );
	open( FILE, ">$fullpath" );
	binmode FILE;
	if( $data ) { print FILE $data; }
	close(FILE);
#  print "Done.\n\n";
    }
}

read_feedlist(".feeds");
