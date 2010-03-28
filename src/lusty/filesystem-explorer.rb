# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

module Lusty
class FilesystemExplorer < Explorer
  public
    def initialize
      super
      @prompt = FilesystemPrompt.new
      @memoized_entries = {}
    end

    def run
      FileMasks.create_glob_masks()
      @vim_swaps = VimSwaps.new
      super
    end

    def run_from_here
      start_path = if $curbuf.name.nil?
                     VIM::getcwd()
                   else
                     VIM::evaluate("expand('%:p:h')")
                   end

      @prompt.set!(start_path + File::SEPARATOR)
      run()
    end

    def run_from_wd
      @prompt.set!(VIM::getcwd() + File::SEPARATOR)
      run()
    end

    def key_pressed()
      i = VIM::evaluate("a:code_arg").to_i

      case i
      when 1, 10  # <C-a>, <Shift-Enter>
        cleanup()
        # Open all non-directories currently in view.
        @ordered_matching_entries.each do |e|
          path_str = \
            if @prompt.at_dir?
              @prompt.input + e.name
            else
              @prompt.dirname + File::SEPARATOR + e.name
            end

          load_file(path_str, :current_tab) unless File.directory?(path_str)
        end
      when 5      # <C-e> edit file, create it if necessary
        if not @prompt.at_dir?
          cleanup()
          # Force a reread of this directory so that the new file will
          # show up (as long as it is saved before the next run).
          @memoized_entries.delete(view_path())
          load_file(@prompt.input, :current_tab)
        end
      when 18     # <C-r> refresh
        @memoized_entries.delete(view_path())
        refresh(:full)
      else
        super
      end
    end

  private
    def title
    '[LustyExplorer-Files]'
    end

    def on_refresh
      if VIM::has_syntax?
        VIM::command 'syn clear LustyExpFileWithSwap'

        view = view_path()
        @vim_swaps.file_names.each do |file_with_swap|
          if file_with_swap.dirname == view
            base = file_with_swap.basename
            match_str = Displayer.vim_match_string(base.to_s, false)
            VIM::command "syn match LustyExpFileWithSwap \"#{match_str}\""
          end
        end
      end

      # TODO: restore highlighting for open buffers?
    end

    def current_abbreviation
      if @prompt.at_dir?
        ""
      else
        File.basename(@prompt.input)
      end
    end

    def view_path
      input = @prompt.input

      path = \
        if @prompt.at_dir? and \
           input.length > 1         # Not root
          # The last element in the path is a directory + '/' and we want to
          # see what's in it instead of what's in its parent directory.

          Pathname.new(input[0..-2])  # Canonicalize by removing trailing '/'
        else
          Pathname.new(input).dirname
        end

      return path
    end

    def all_entries
      view = view_path()

      unless @memoized_entries.has_key?(view)

        if not view.directory?
          return []
        elsif not view.readable?
          # TODO: show "-- PERMISSION DENIED --"
          return []
        end

        # Generate an array of the files
        entries = []
        view_str = view.to_s
        unless Lusty::ends_with?(view_str, File::SEPARATOR)
          # Don't double-up on '/' -- makes Cygwin sad.
          view_str << File::SEPARATOR
        end

        Dir.foreach(view_str) do |name|
          next if name == "."   # Skip pwd
          next if name == ".." and Lusty::option_set?("AlwaysShowDotFiles")

          # Hide masked files.
          next if FileMasks.masked?(name)

          if FileTest.directory?(view_str + name)
            name << File::SEPARATOR
          end
          entries << Entry.new(name)
        end
        @memoized_entries[view] = entries
      end

      all = @memoized_entries[view]

      if Lusty::option_set?("AlwaysShowDotFiles") or \
         current_abbreviation()[0] == ?.
        all
      else
        # Filter out dotfiles if the current abbreviation doesn't start with
        # '.'.
        all.select { |x| x.name[0] != ?. }
      end
    end

    def open_entry(entry, open_mode)
      path = view_path() + entry.name

      if File.directory?(path)
        # Recurse into the directory instead of opening it.
        @prompt.set!(path.to_s)
      elsif entry.name.include?(File::SEPARATOR)
        # Don't open a fake file/buffer with "/" in its name.
        return
      else
        cleanup()
        load_file(path.to_s, open_mode)
      end
    end

    def load_file(path_str, open_mode)
      Lusty::assert($curwin == @calling_window)
      # Escape for Vim and remove leading ./ for files in pwd.
      filename_escaped = VIM::filename_escape(path_str).sub(/^\.\//,"")
      single_quote_escaped = VIM::single_quote_escape(filename_escaped)
      sanitized = VIM::evaluate "fnamemodify('#{single_quote_escaped}', ':.')"
      cmd = case open_mode
            when :current_tab
              "e"
            when :new_tab
              "tabe"
            when :new_split
	      "sp"
            when :new_vsplit
	      "vs"
            else
              Lusty::assert(false, "bad open mode")
            end

      VIM::command "silent #{cmd} #{sanitized}"
    end
end
end
