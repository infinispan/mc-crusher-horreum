#!/usr/bin/perl -w

# apt install -y perl libcache-memcached-perl libwww-curl-simple-perl libhttp-tinyish-perl libjson-perl

# Usage: mc-crusher [timeoutInSecs]. For example: mc-crusher.pl 60

use strict;
use warnings;

use Cache::Memcached;
use Data::Dumper;
use Time::Piece;
use JSON;
use WWW::Curl::Simple;
use HTTP::Tiny;
use Cwd;
use File::Basename;

my $port = 11211;
my $duration = shift @ARGV || 5 * 60; # 5 mins
my @hosts = '127.0.0.1';
my $dir = cwd."/benchmark/";
print "Dir of benchmark: $dir\n";
my @configs = glob( $dir . '*' );
print "Configs: @configs\n";

my $horreumPassword = $ENV{'HORREUM_PASSWORD'} or die "Env variable 'HORREUM_PASSWORD' is not set!";
my $horreumUsername = $ENV{'HORREUM_USERNAME'} or die "Env variable 'HORREUM_USERNAME' is not set!";
my $keyCloakURL = $ENV{'KEYCLOAK_URL'} or die "Env variable KEYCLOAK_URL is not set!";
my $horreumURL = $ENV{'HORREUM_URL'} or die "Env variable HORREUM_URL is not set!";

foreach my $config (@configs) {
        my $configName = basename($config);
        foreach my $host (@hosts) {
                print "ConfigName: $configName\n";
                my $serverAddr = "$host:$port";
                print "Server: $serverAddr\n";

                my $memcached = new Cache::Memcached;

                my @servers = ($serverAddr);
                $memcached->set_servers(\@servers);
                my $stats = $memcached->stats([ 'misc' ])->{'hosts'}->{$serverAddr}->{'misc'};
                my $stat = int($stats->{'uptime'});
                print "Stat: $stat\n";
                die "Memcached is not running on $host!" if $stat == 0;
                $memcached->flush_all();

                my $stats_before = $memcached->stats([ 'misc' ])->{'hosts'}->{$serverAddr}->{'misc'};
                my $stat_before = int($stats_before->{$configName});
                print "Stat before: $stat_before\n";
                warn "Stat before: $stat_before\n";

                print "Going to test $config at $host...\n";
                my $timeBefore = localtime->strftime('%Y-%m-%dT%H:%M:%SZ');

                system("./mc-crusher --conf $config --ip $host --port $port --timeout $duration") == 0
                    or die "MC Crusher status ($?): $!\n";

                my $timeAfter = localtime->strftime('%Y-%m-%dT%H:%M:%SZ');
                $stats = $memcached->stats([ 'misc' ])->{'hosts'}->{$serverAddr}->{'misc'};
                print "Stats: " . Dumper($stats);
                #warn Dumper($stats);
                # my $stat_after = int($stats->{$config});
                my $stat_after = int($stats->{$configName});
                warn "Stat after: $stat_after\n\n";
                my $stat_diff = $stat_after - $stat_before;
                warn "Stat diff: $stat_diff\n";
                my $cmd_per_sec = $stat_diff / $duration;
                warn "Cmd per second: $cmd_per_sec\n";
                my $bytes_written = $stats->{'bytes_written'};
                my $bytes_read = $stats->{'bytes_read'};
                my $time_system = $stats->{'rusage_system'};
                my $time_user = $stats->{'rusage_user'};

                my $today = localtime->ymd();
                my $folder = "/tmp/results/$today";
                system("mkdir -p $folder");
                print "Cannot create '$folder': $!\n" if $!;
                # my $filename = "$folder/memcached-mc-crusher-report-$host-$config.csv";
                my $filename = "$folder/memcached-mc-crusher-report-$host-$configName.csv";

                my $headerPrefix = "${host}_${configName}";
                open(my $fh, '>', $filename) or die "Could not open file '$filename': $!";
                print $fh "timeStamp,${headerPrefix}_per_sec,${headerPrefix}_bytes_written,${headerPrefix}_bytes_read," .
                    "${headerPrefix}_time_system,${headerPrefix}_time_user,config,host\n";
                print $fh "$timeAfter,$cmd_per_sec,$bytes_written,$bytes_read,$time_system,$time_user,$configName,$host\n";
                close $fh;

                my %rec_hash = ('$schema' => "urn:mc-crush-schema:1.0", 'throughput' => $cmd_per_sec, 'configName' => $configName,  'stats' => $stats);
                my $jsonHorreum = encode_json \%rec_hash;
                print "$jsonHorreum\n";

                my $filenameJson = "$folder/memcached-mc-crusher-report-$host-$configName.json";
                open(my $f, '>', $filenameJson) or die "Could not open file '$filenameJson': $!";
                print $f "$jsonHorreum\n";
                close $f;

                my $ua = HTTP::Tiny->new();
                my $res = $ua->request(
                    'POST' =>
                        "$keyCloakURL/realms/horreum/protocol/openid-connect/token",
                    {
                        headers => {
                            'Content-Type' => 'application/x-www-form-urlencoded'
                        },
                        content =>
                            "username=$horreumUsername&password=$horreumPassword&grant_type=password&client_id=horreum-ui"
                    },
                );

                ($res->{content} =~ /"access_token":"([^"]+)"/) or die "Cannot find access_token in response: $res->{content}";

                my $jsonResponse = decode_json($res->{content});
                my $token = $jsonResponse->{access_token};
                my $test = 'MC-CRUSHER';
                my $owner = 'jdg-qe-team';
                my $access = 'PUBLIC';

                print "${horreumURL}/api/run/data?access=$access&owner=$owner&start=$timeBefore&stop=$timeAfter&test=$test";
                my $resUpload = $ua->request(
                    'POST' =>
                        "${horreumURL}/api/run/data?access=$access&owner=$owner&start=$timeBefore&stop=$timeAfter&test=$test",
                    {
                        headers => {
                            'Authorization' => "Bearer $token",
                            'Content-Type'  => 'application/json'
                        },
                        content => "$jsonHorreum"
                    },
                );
                print("$resUpload->{status} $resUpload->{reason}\n");
        }
}
print "=========================\n\tDONE\n=========================\n";
