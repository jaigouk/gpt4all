# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gpt4all::ConversationalAI do
  let(:gpt4all) { Gpt4all::ConversationalAI.new }
  let(:response_body) { 'This is a mock file content.' }

  let(:executable_url) { gpt4all.send(:determine_upstream_url) }
  let(:md5_url) { "https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/#{gpt4all.model}.bin.md5" }
  let(:model_url) { "https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/#{gpt4all.model}.bin" }
  let(:md5_path) { "#{gpt4all.model_path}.md5" }
  let(:mock_md5) { Digest::MD5.hexdigest(response_body) }

  before do
    gpt4all.model_path = File.join(File.dirname(__FILE__), 'fixtures', 'model.bin')
    gpt4all.executable_path = File.join(File.dirname(__FILE__), 'fixtures', 'gpt4all_executable')

    stub_request(:get, executable_url)
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'identity', 'User-Agent' => 'Faraday v2.7.4' })
      .to_return(status: 200, body: response_body, headers: {})

    stub_request(:get, model_url)
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'identity', 'User-Agent' => 'Faraday v2.7.4' })
      .to_return(status: 200, body: response_body, headers: {})

    stub_request(:get, md5_url)
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'identity', 'User-Agent' => 'Faraday v2.7.4' })
      .to_return(status: 200, body: mock_md5, headers: {})
  end

  describe '#prepare_resources' do
    it 'calls download_executable and download_model if force_download is true' do
      allow(gpt4all).to receive(:download_executable).and_call_original
      allow(gpt4all).to receive(:download_model).and_call_original
      allow(gpt4all).to receive(:download_md5_file).and_return(true)
      allow(gpt4all).to receive(:write_chunks_to_file).and_return(true)

      fixture_md5_path = File.join(File.dirname(__FILE__), 'fixtures', 'model_md5.txt')
      File.write(md5_path, File.read(fixture_md5_path))
      File.write(gpt4all.model_path, response_body)

      gpt4all.prepare_resources(force_download: true)

      expect(gpt4all).to have_received(:download_executable)
      expect(gpt4all).to have_received(:download_model)
      expect(gpt4all).to have_received(:download_md5_file)
    end
  end

  describe '#download_with_progress_bar' do
    context 'when an incomplete file is downloaded' do
      it 'raises an error' do
        incomplete_response_body = 'This is a mock file content'
        incomplete_response = Struct.new(:body).new(StringChunksWrapper.new(incomplete_response_body))

        allow(incomplete_response).to receive(:headers).and_return(
          'Content-Length' => incomplete_response_body.length * 2
        )
        allow(incomplete_response.body).to receive(:each).and_yield(incomplete_response_body)

        expect do
          gpt4all.send(:download_with_progress_bar, incomplete_response, 'model.bin',
                       incomplete_response_body.length * 2)
        end.to raise_error(RuntimeError, 'Incomplete file downloaded.')
      end
    end

    context 'when a network error occurs during download' do
      it 'raises an error' do
        model_url = "https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/#{gpt4all.model}.bin"

        stub_request(:get, model_url)
          .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'identity', 'User-Agent' => 'Faraday v2.7.4' })
          .to_raise(Faraday::ConnectionFailed.new('Network error'))

        expect do
          gpt4all.send(:download_with_progress_bar, gpt4all.send(:create_faraday_connection, model_url), 'model.bin',
                       100)
        end.to raise_error(Faraday::ConnectionFailed, 'Network error')
      end
    end
  end

  describe '#verify_md5_signature' do
    before do
      gpt4all.model_path = File.join(File.dirname(__FILE__), 'fixtures', 'model.bin')
      gpt4all.executable_path = File.join(File.dirname(__FILE__), 'fixtures', 'gpt4all_executable')

      stub_request(:get, executable_url)
        .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'identity', 'User-Agent' => 'Faraday v2.7.4' })
        .to_return(status: 200, body: 'This is a mock file content.', headers: {})

      stub_request(:get, model_url)
        .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'identity', 'User-Agent' => 'Faraday v2.7.4' })
        .to_return(status: 200, body: 'This is a mock file content.', headers: {})

      stub_request(:get, md5_url)
        .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'identity', 'User-Agent' => 'Faraday v2.7.4' })
        .to_return(status: 200, body: mock_md5, headers: {})
    end

    context 'when MD5 check is successful' do
      it 'does not raise an error' do
        File.write(md5_path, mock_md5)
        File.write(gpt4all.model_path, response_body)

        expect { gpt4all.send(:verify_md5_signature) }.not_to raise_error
      end
    end

    context 'when MD5 check fails' do
      it 'raises an MD5 signature mismatch error' do
        File.write(md5_path, mock_md5)
        File.write(gpt4all.model_path, 'Different content')

        expect { gpt4all.send(:verify_md5_signature) }.to raise_error(RuntimeError, 'MD5 signature mismatch.')
      end
    end

    context 'when MD5 file is not found' do
      it 'raises an MD5 file not found error' do
        FileUtils.rm_f(md5_path)

        expect { gpt4all.send(:verify_md5_signature) }.to raise_error(RuntimeError, 'MD5 file not found.')
      end
    end
  end

  describe '#start_bot' do
    it 'starts the bot and waits for it to be ready' do
      gpt4all.prepare_resources

      allow_any_instance_of(IO).to receive(:read_nonblock).and_return('Bot is ready >')

      gpt4all.start_bot
      expect(gpt4all.instance_variable_get(:@bot)).not_to be_nil, "Expected bot to be started, but it's not."
    end
  end

  describe '#stop_bot' do
    it 'stops the bot and cleans up resources' do
      allow_any_instance_of(IO).to receive(:read_nonblock).and_return('Bot is ready >')
      gpt4all.prepare_resources
      gpt4all.start_bot

      expect(gpt4all.instance_variable_get(:@bot)).not_to be_nil, "Expected bot to be started, but it's not."

      allow_any_instance_of(IOError).to receive(:close).and_return('Bot is finished >')

      gpt4all.stop_bot

      error_msg = "Expected bot to be stopped and cleaned up, but it's still running."

      expect(gpt4all.instance_variable_get(:@bot)).to be_nil, error_msg
    end
  end

  describe '#prompt' do
    context 'when bot is initialized' do
      it 'returns a response' do
        allow_any_instance_of(IO).to receive(:read_nonblock).and_return('Bot is ready >',
                                                                        'This is a sample response.',
                                                                        '>', 'Another response.')
        gpt4all.prepare_resources
        gpt4all.start_bot

        gpt4all.test_mode = true
        response = gpt4all.prompt('What is your name?')
        expect(response).not_to be_empty
      end
    end

    context 'when bot is not initialized' do
      it 'raises an error' do
        gpt4all.stop_bot
        expect { gpt4all.prompt('What is your name?') }.to raise_error(RuntimeError, 'Bot is not initialized.')
      end
    end
  end
end
