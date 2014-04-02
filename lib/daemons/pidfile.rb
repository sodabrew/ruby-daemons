require 'daemons/pid'

module Daemons
  # === What is a Pid-File?
  # A <i>Pid-File</i> is a file containing the <i>process identification number</i>
  # (pid) that is stored in a well-defined location of the filesystem thus allowing other
  # programs to find out the pid of a running script.
  #
  # Daemons needs the pid of the scripts that are currently running in the background
  # to send them so called _signals_. Daemons uses the +TERM+ signal to tell the script
  # to exit when you issue a +stop+ command.
  #
  # === How does a Pid-File look like?
  #
  # Pid-Files generated by Daemons have to following format:
  #   <scriptname>.rb<number>.pid
  # (Note that <tt><number></tt> is omitted if only one instance of the script can
  # run at any time)
  #
  # Each file just contains one line with the pid as string (for example <tt>6432</tt>).
  #
  # === Where are the Pid-Files stored?
  #
  # Daemons is configurable to store the Pid-Files relative to three different locations:
  # 1.  in a directory relative to the directory where the script (the one that is supposed to run
  #     as a daemon) resides (<tt>:script</tt> option for <tt>:dir_mode</tt>)
  # 2.  in a directory given by <tt>:dir</tt> (<tt>:normal</tt> option for <tt>:dir_mode</tt>)
  # 3.  in the preconfigured directory <tt>/var/run</tt> (<tt>:system</tt> option for <tt>:dir_mode</tt>)
  #
  class PidFile < Pid
    attr_reader :dir, :progname, :multiple, :number

    def self.find_files(dir, progname, delete = false)
      files = Dir[File.join(dir, "#{progname}*.pid")]

      files.delete_if { |f| not (File.file?(f) and File.readable?(f)) }
      if delete
        files.delete_if do |f|
          pid = File.open(f) { |h| h.read }.to_i
          rsl =  !Pid.running?(pid)
          if rsl
            puts "pid-file for killed process #{pid} found (#{f}), deleting."
            begin; File.unlink(f); rescue ::Exception; end
          end
          rsl
        end
      end

      files
    end

    def self.existing(path)
      new_instance = PidFile.allocate

      new_instance.instance_variable_set(:@path, path)

      def new_instance.filename
        @path
      end

      new_instance
    end

    def initialize(dir, progname, multiple = false)
      @dir = File.expand_path(dir)
      @progname = progname
      @multiple = multiple
      @number = nil
      @number = 0 if multiple

      if multiple
        while File.exist?(filename) && @number < 1024
          @number += 1
        end

        if @number >= 1024
          fail RuntimeException('cannot run more than 1024 instances of the application')
        end
      end
    end

    def filename
      File.join(@dir, "#{@progname}#{ @number || '' }.pid")
    end

    def exist?
      File.exist? filename
    end

    def pid=(p)
      File.open(filename, 'w') do |f|
        f.chmod(0644)
        f.puts p   # Process.pid
      end
    end

    def cleanup
      File.delete(filename) if pid == Process.pid
    end

    def pid
      begin
        File.open(filename) do |f|
          p = f.gets.to_i
          return nil if p == 0 # Otherwise an invalid pid file becomes pid 0
          return p
        end
      rescue ::Exception
        return nil
      end
    end
  end
end
