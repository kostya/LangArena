#!/usr/bin/env ruby
def mem(pid); `ps p #{pid} -o rss`.split.last.to_i; end
name = "#{ARGV[0]}"
name += " #{ARGV[1]}" if ARGV[1] && ARGV[1].start_with?("--")

t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
pid = Process.spawn(*ARGV.to_a)
mm = 0

Thread.new do
  mm = mem(pid)
  while true
    sleep 0.03
    m = mem(pid)
    mm = m if m > mm
  end
end

Process.waitall
t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
STDERR.puts "mem_usage: %.1fMb" % [mm / 1024.0]
