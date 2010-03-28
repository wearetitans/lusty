# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

# Utility functions.
module Lusty
  MOST_POSITIVE_FIXNUM = 2**(0.size * 8 -2) -1

  def self.simplify_path(s)
    s = s.gsub(/\/+/, '/')  # Remove redundant '/' characters
    begin
      if s[0] == ?~
        # Tilde expansion - First expand the ~ part (e.g. '~' or '~steve')
        # and then append the rest of the path.  We can't just call
        # expand_path() or it'll throw on bad paths.
        s = File.expand_path(s.sub(/\/.*/,'')) + \
            s.sub(/^[^\/]+/,'')
      end

      if s == '/'
        # Special-case root so we don't add superfluous '/' characters,
        # as this can make Cygwin choke.
        s
      elsif ends_with?(s, File::SEPARATOR)
        File.expand_path(s) + File::SEPARATOR
      else
        dirname_expanded = File.expand_path(File.dirname(s))
        if dirname_expanded == '/'
          dirname_expanded + File.basename(s)
        else
          dirname_expanded + File::SEPARATOR + File.basename(s)
        end
      end
    rescue ArgumentError
      s
    end
  end

  def self.ready_for_read?(io)
    if io.respond_to? :ready?
      ready?
    else
      result = IO.select([io], nil, nil, 0)
      result && (result.first.first == io)
    end
  end

  def self.ends_with?(s1, s2)
    tail = s1[-s2.length, s2.length]
    tail == s2
  end

  def self.starts_with?(s1, s2)
    head = s1[0, s2.length]
    head == s2
  end

  def self.option_set?(opt_name)
    opt_name = "g:LustyExplorer" + opt_name
    VIM::evaluate_bool("exists('#{opt_name}') && #{opt_name} != '0'")
  end

  def self.profile
    # Profile (if enabled) and provide better
    # backtraces when there's an error.

    if $LUSTY_PROFILING
      if not RubyProf.running?
        RubyProf.measure_mode = RubyProf::WALL_TIME
        RubyProf.start
      else
        RubyProf.resume
      end
    end

    begin
      yield
    rescue Exception => e
      puts e
      puts e.backtrace
    end

    if $LUSTY_PROFILING and RubyProf.running?
      RubyProf.pause
    end
  end

  class AssertionError < StandardError ; end

  def self.assert(condition, message = 'assertion failure')
    raise AssertionError.new(message) unless condition
  end

  def self.d(s)
    # (Debug print)
    $stderr.puts s
  end
end
