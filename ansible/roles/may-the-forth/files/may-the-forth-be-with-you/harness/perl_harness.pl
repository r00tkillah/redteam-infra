#!/usr/bin/env perl
use strict;
use warnings;
use Config;

my $SYS_READ = 0;
my $SYS_MMAP = 9;
my $SYS_MPROTECT = 10;
my $SYS_RT_SIGACTION = 13;
my $SYS_GETPID = 39;
my $SYS_GETTID = 186;
my $SYS_TGKILL = 234;
my $PROT_READ = 1;
my $PROT_WRITE = 2;
my $PROT_EXEC = 4;
my $MAP_PRIVATE = 2;
my $MAP_ANONYMOUS = 0x20;
my $SIGUSR2 = 12;
my $SA_RESTORER = 0x04000000;
my $MAX_BUNDLE_SIZE = 17 * 1024 * 1024;
my $SIGNAL_PREFIX = "\xf3\x0f\x1e\xfa\x31\xff\xe9\x09\x00\x00\x00\xb8\x0f\x00\x00\x00\x0f\x05\x0f\x0b";
my $SIGNAL_RESTORER_OFFSET = 11;

sub open_bounded_input {
    my ($path, $maximum, $prefix) = @_;
    open(my $source, "<:raw", $path) or die "perl_harness: open: $!\n";
    my $length = -s $source;
    if (!defined($length) || $length <= length($prefix) || $length > $maximum) {
        die "perl_harness: invalid bundle length\n";
    }
    my $actual_prefix = "";
    read($source, $actual_prefix, length($prefix)) == length($prefix)
        or die "perl_harness: short prefix\n";
    $actual_prefix eq $prefix or die "perl_harness: missing signal-entry prefix\n";
    seek($source, 0, 0) or die "perl_harness: seek: $!\n";
    return ($source, $length);
}

if ($^O ne "linux" || $Config{archname} !~ /x86_64/ || $Config{ptrsize} != 8) {
    die "perl_harness: Linux x86-64 Perl is required\n";
}
if (@ARGV != 2 || $ARGV[0] ne "--embedded-signal") {
    die "usage: $0 --embedded-signal bundle\n";
}

my $path = $ARGV[1];
my ($source, $length) = open_bounded_input($path, $MAX_BUNDLE_SIZE, $SIGNAL_PREFIX);

my $mapping_length = ($length + 4095) & ~4095;
my $base = syscall($SYS_MMAP, 0, $mapping_length, $PROT_READ | $PROT_WRITE,
                   $MAP_PRIVATE | $MAP_ANONYMOUS, -1, 0);
$base != -1 or die "perl_harness: mmap: $!\n";
my $done = 0;
while ($done < $length) {
    my $copied = syscall($SYS_READ, fileno($source), $base + $done, $length - $done);
    if ($copied == -1 && $!{EINTR}) {
        next;
    }
    $copied > 0 or die "perl_harness: short bundle read\n";
    $done += $copied;
}
close($source) or die "perl_harness: close: $!\n";
syscall($SYS_MPROTECT, $base, $mapping_length, $PROT_READ | $PROT_EXEC) == 0
    or die "perl_harness: mprotect: $!\n";

my $action = pack("Q<Q<Q<Q<", $base, $SA_RESTORER, $base + $SIGNAL_RESTORER_OFFSET, 0);
syscall($SYS_RT_SIGACTION, $SIGUSR2, $action, 0, 8) == 0
    or die "perl_harness: rt_sigaction: $!\n";
my $pid = syscall($SYS_GETPID);
my $tid = syscall($SYS_GETTID);
syscall($SYS_TGKILL, $pid, $tid, $SIGUSR2) == 0
    or die "perl_harness: tgkill: $!\n";
die "perl_harness: signal entry returned\n";
