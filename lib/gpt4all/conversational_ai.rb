# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'os'
require 'faraday'
require 'tty-progressbar'

module Gpt4all
  # rubocop:disable Metrics/ClassLength
  class ConversationalAI
    attr_accessor :model, :decoder_config, :executable_path, :model_path, :force_download, :test_mode

    # https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/gpt4all-lora-quantized.bin
    OSX_INTEL_URL = 'https://github.com/nomic-ai/gpt4all/blob/main/chat/gpt4all-lora-quantized-OSX-intel?raw=true'
    OSX_M1_URL = 'https://github.com/nomic-ai/gpt4all/blob/main/chat/gpt4all-lora-quantized-OSX-m1?raw=true'
    LINUX_URL = 'https://github.com/nomic-ai/gpt4all/blob/main/chat/gpt4all-lora-quantized-linux-x86?raw=true'
    WINDOWS_URL = 'https://github.com/nomic-ai/gpt4all/blob/main/chat/gpt4all-lora-quantized-win64.exe?raw=true'

    # rubocop:disable Metrics/MethodLength
    def initialize(model: 'gpt4all-lora-quantized', force_download: false, decoder_config: {})
      @bot = nil
      @model = model
      @decoder_config = decoder_config
      @executable_path = "#{Dir.home}/.nomic/gpt4all"
      @model_path = "#{Dir.home}/.nomic/#{model}.bin"
      @force_download = force_download
      @test_mode = false

      return unless %w[gpt4all-lora-quantized gpt4all-lora-unfiltered-quantized].none?(model)

      raise "Model #{model} is not supported. Current models supported are:
                  gpt4all-lora-quantized
                  gpt4all-lora-unfiltered-quantized"
    end
    # rubocop:enable Metrics/MethodLength

    def prepare_resources(force_download: false)
      download_promises = []

      download_promises << download_executable if force_download || !File.exist?(executable_path)
      download_promises << download_model if force_download || !File.exist?(model_path)

      download_promises.compact.each(&:call)
    end

    def start_bot
      stop_bot if bot

      spawn_args = [executable_path, '--model', model_path]

      decoder_config.each do |key, value|
        spawn_args.push("--#{key}", value.to_s)
      end

      @bot = Open3.popen2e(*spawn_args)
      @bot_pid = bot.last.pid

      wait_for_bot_ready
    end

    def stop_bot
      return unless bot

      bot[0].close
      bot[1].close
      bot[2].exit
      @bot = nil
      @bot_pid = nil
    end

    def restart_bot
      stop_bot
      start_bot
    end

    def prompt(input)
      ensure_bot_is_ready

      begin
        bot.first.puts(input)
        response = read_from_bot
      rescue StandardError => e
        puts "Error during prompt: #{e.message}"
        restart_bot
        response = prompt(input)
      end

      response
    end

    private

    attr_reader :bot

    def download_executable
      FileUtils.mkdir_p(File.dirname(executable_path))
      download_file(determine_upstream_url, executable_path)
      FileUtils.chmod(0o755, executable_path)
      puts "File downloaded successfully to #{executable_path}"
    end

    def determine_upstream_url
      if OS.mac?
        OS.host_cpu == 'x86_64' ? OSX_INTEL_URL : OSX_M1_URL
      elsif OS.linux?
        LINUX_URL
      elsif OS.windows?
        WINDOWS_URL
      else
        raise 'Unsupported platform. Supported: OSX (ARM and Intel), Linux, Windows.'
      end
    end

    def download_model
      model_url = "https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/#{model}.bin"
      download_file(model_url, model_path)
      download_md5_file
      verify_md5_signature

      puts "File downloaded successfully to #{model_path}"
    end

    def download_file(url, destination)
      response = create_faraday_connection(url)
      total_size = response.headers['Content-Length'].to_i
      create_destination_directory(destination)
      download_with_progress_bar(response, destination, total_size)
      puts "File downloaded successfully to #{destination}"
    end

    def create_faraday_connection(url)
      connection = Faraday.new(url) do |f|
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end

      connection.get do |request|
        request.headers['Accept-Encoding'] = 'identity'
      end
    end

    def create_destination_directory(destination)
      FileUtils.mkdir_p(File.dirname(destination))
    end

    def download_with_progress_bar(response, destination, total_size)
      progress_bar = TTY::ProgressBar.new(
        '[:bar] :percent :etas',
        complete: '=',
        incomplete: ' ',
        width: 20,
        total: total_size
      )

      write_chunks_to_file(response, destination, progress_bar)
    end

    def write_chunks_to_file(response, destination, progress_bar)
      File.open(destination, 'wb') do |file|
        downloaded_size = 0
        response.body.each_chunk do |chunk|
          progress_bar.advance(chunk.bytesize)
          file.write(chunk)
          downloaded_size += chunk.bytesize
        end
        raise 'Incomplete file downloaded.' if downloaded_size < progress_bar.total
      end
    end

    def download_md5_file
      md5_url = "https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/#{model}.bin.md5"
      md5_path = "#{model_path}.md5"
      download_file(md5_url, md5_path)
    end

    def verify_md5_signature
      md5_path = "#{model_path}.md5"
      raise 'MD5 file not found.' unless File.exist?(md5_path)

      expected_md5 = File.read(md5_path).strip
      actual_md5 = Digest::MD5.file(model_path).hexdigest
      raise 'MD5 signature mismatch.' unless expected_md5 == actual_md5

      puts 'MD5 signature verified successfully.'
    end

    # remove the stop character from end of the output
    def strip_stop(output, stop)
      output[0...output.rindex(stop)]
    end

    def read_from_bot(stop: '>')
      output = ''
      loop do
        new_output = bot[1].read_nonblock(2048)
        output += new_output
        return strip_stop(output, stop) if new_output&.include?(stop)

      rescue IO::WaitReadable
        bot[1].wait_readable
        retry
      end
    end

    def wait_for_bot_ready
      read_from_bot
    end

    def ensure_bot_is_ready
      raise 'Bot is not initialized.' unless bot
    end
  end
  # rubocop:enable Metrics/ClassLength
end
