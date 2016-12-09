require "worker_scoreboard/version"
require 'digest/md5'
require 'fileutils'

class WorkerScoreboard
  def initialize(base_dir)
    fail 'mandatory parameter:base_dir is missing' if base_dir.nil?
    @base_dir = base_dir

    @fh = nil
    @id_for_fh = nil

    # [path, filehandler]
    @data = [build_filename, @fh]
    @clean_proc = Remover.new(@data)
    ObjectSpace.define_finalizer(self, @clean_proc)

    unless Dir.exist? @base_dir
      FileUtils.mkdir_p @base_dir or fail "failed to create directory:#{@base_dir}:#{$!}"
    end
    begin
      File.unlink build_filename
    rescue
    end
  end

  def update(status)
    if !@fh.nil? && @id_for_fh != worker_id
      @fh.close
      @fh = nil
    end

    if @fh.nil?
      filename = build_filename
      tmp_filename = "#{filename}.tmp"
      f = File.open(tmp_filename, 'wb')
      f.flush
      f.flock File::LOCK_EX or raise "failed to flock LOCK_EX file:#{tmp_filename}:#{$!}"
      File.rename(tmp_filename, filename) or raise "failed to rename file:#{tmp_filename} to #{filename}:#{$!}"
      @fh = f
      @id_for_fh = worker_id
    end
    @fh.seek 0 or raise "seek failed:#{$!}";
    @fh.write("#{Digest::MD5.digest(status)}#{[status.length].pack("N*")}#{status}")
    @fh.flush
  end

  def read_all
    ret = {}
    for_all do |id, fh|
      10.times do
        fh.seek 0 or raise "seek failed:#{$!}"
        data = fh.read
        break if data.length < 16 + 4
        md5 = data[0, 16]
        size = data[16, 4].unpack("N*")
        status = data[20, size[0]]
        next if Digest::MD5.digest(status) != md5
        ret[id] = status
        break
      end
      #warn "failed to read status of id:#{id}, skipping"
    end
    ret
  end

  def cleanup
    for_all
  end

  private

  def worker_id
    Process.pid
  end

  def for_all
    files =  Dir.glob("#{@base_dir}/status_*")
    files.each do |file|
      file =~ /\/status_(.*)$/ or next
      id = $1.to_i
      fh = File.open(file, 'r+b') or next
      if id != worker_id && fh.flock(File::LOCK_EX|File::LOCK_NB)
        fh.close
        begin
          File.unlink file
        rescue => e
          warn "failed to remove an obsolete scoreboard file:#{file}:#{$!}" unless e === Errno::ENOENT
        end
        next
      end
      yield id, fh
      fh.close
    end
  end

  def build_filename
    "#{@base_dir}/status_#{worker_id}"
  end

  class Remover
    def initialize(data)
      @pid = $$
      @data = data
    end

    def call(*args)
      return if @pid != $$
      path, tmpfile = @data
      STDERR.print "removing ", path, "..." if $DEBUG
      tmpfile.close if tmpfile
      if path
        begin
          File.unlink(path)
        rescue Errno::ENOENT
        end
      end
      STDERR.print "done\n" if $DEBUG
    end
  end

end
