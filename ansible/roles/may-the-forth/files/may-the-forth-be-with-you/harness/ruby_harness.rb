#!/usr/bin/env ruby
begin
  require "fiddle"
rescue LoadError
  warn "ruby_harness: this Ruby was built without standard-library Fiddle"
  exit 2
end

unless RUBY_PLATFORM.match?(/x86_64-linux/)
  warn "ruby_harness: Linux x86-64 is required"
  exit 2
end

unless ARGV.length == 2 && ARGV[0] == "--embedded-raw"
  warn "usage: #{$PROGRAM_NAME} --embedded-raw bundle"
  exit 2
end

MAX_BUNDLE_SIZE = 17 * 1024 * 1024
PROT_READ = 1
PROT_WRITE = 2
PROT_EXEC = 4
MAP_PRIVATE = 2
MAP_ANONYMOUS = 0x20

def read_bounded_input(path)
  expected = File.size(path)
  data = File.binread(path)
  if expected.zero? || expected > MAX_BUNDLE_SIZE || data.bytesize != expected
    warn "ruby_harness: invalid bundle length"
    exit 2
  end
  data
end

bundle = read_bounded_input(ARGV[1])

libc = Fiddle.dlopen(nil)
mmap = Fiddle::Function.new(
  libc["mmap"],
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_INT,
   Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_LONG],
  Fiddle::TYPE_VOIDP
)
mprotect = Fiddle::Function.new(
  libc["mprotect"],
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_INT],
  Fiddle::TYPE_INT
)

mapping_size = (bundle.bytesize + 4095) & ~4095
address = mmap.call(0, mapping_size, PROT_READ | PROT_WRITE,
                    MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
if address.to_i == -1
  warn "ruby_harness: mmap failed"
  exit 2
end
Fiddle::Pointer.new(address)[0, bundle.bytesize] = bundle
unless mprotect.call(address, mapping_size, PROT_READ | PROT_EXEC).zero?
  warn "ruby_harness: mprotect failed"
  exit 2
end

entry = Fiddle::Function.new(address, [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
entry.call(0)
exit 111
