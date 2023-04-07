# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gpt4all::ConversationalAI do
  let(:gpt4all) { Gpt4all::ConversationalAI.new }
  let(:response_body) { 'This is a mock file content.' }

  before do
    executable_url = gpt4all.send(:determine_upstream_url)
    model_url = "https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/#{gpt4all.model}.bin"

    stub_request(:get, executable_url)
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'identity', 'User-Agent' => 'Faraday v2.7.4' })
      .to_return(status: 200, body: 'This is a mock file content.', headers: {})

    stub_request(:get, model_url)
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'identity', 'User-Agent' => 'Faraday v2.7.4' })
      .to_return(status: 200, body: 'This is a mock file content.', headers: {})
  end

  describe '#prepare_resources' do
    it 'calls download_executable and download_model if force_download is true' do
      allow(gpt4all).to receive(:download_executable).and_call_original
      allow(gpt4all).to receive(:download_model).and_call_original
      allow(gpt4all).to receive(:write_chunks_to_file).and_return(true)

      gpt4all.prepare_resources(force_download: true)

      expect(gpt4all).to have_received(:download_executable)
      expect(gpt4all).to have_received(:download_model)
    end
  end

  describe '#start_bot' do
    it 'starts the bot and waits for it to be ready' do
      gpt4all.prepare_resources

      allow_any_instance_of(Process::Waiter).to receive(:gets).and_return('Bot is ready >')

      gpt4all.start_bot
      expect(gpt4all.instance_variable_get(:@bot)).not_to be_nil, "Expected bot to be started, but it's not."
    end
  end

  describe '#stop_bot' do
    it 'stops the bot and cleans up resources' do
      allow_any_instance_of(Process::Waiter).to receive(:gets).and_return('Bot is ready >')
      gpt4all.prepare_resources
      gpt4all.start_bot

      expect(gpt4all.instance_variable_get(:@bot)).not_to be_nil, "Expected bot to be started, but it's not."

      allow_any_instance_of(Process::Waiter).to receive(:close).and_return('Bot is finished >')

      gpt4all.stop_bot

      error_msg = "Expected bot to be stopped and cleaned up, but it's still running."

      expect(gpt4all.instance_variable_get(:@bot)).to be_nil, error_msg
    end
  end

  describe '#prompt' do
    context 'when bot is initialized' do
      it 'returns a response' do
        allow_any_instance_of(Process::Waiter).to receive(:gets).and_return('Bot is ready >',
                                                                            'This is a sample response.')
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
