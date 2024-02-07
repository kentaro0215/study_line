# frozen_string_literal: true

require 'thor'
require 'httparty'
require 'json'

CONFIG_FILE = File.join(Dir.home, '.stl_config')
CONFIG_JSON = File.join(File.dirname(__FILE__), 'config.json') # config.jsonファイルのパスを指定

module StudyLine
  class CLI < Thor
    desc "configure TOKEN [BASE_URL]", "トークンを設定し、オプショナルでベースURLも設定します。"
    def configure(token, base_url = nil)
      config = { 'CUSTOM_TOKEN' => token }
      config['BASE_URL'] = base_url unless base_url.nil? || base_url.empty?
      File.write(CONFIG_FILE, config.to_json)
      puts "トークン#{'とベースURL' if base_url}が設定されました。"
    end
    

    class Sender
      include HTTParty
      def self.base_uri
        if File.exist?(CONFIG_FILE)
          config = JSON.parse(File.read(CONFIG_FILE))
          config['BASE_URL']
        end
      end
    
    end
    desc "start", "学習セッションの開始時間を記録します。"
    method_option :tag, aliases: "-t", desc: "タグを作成オプション"
    def start
      start_time = Time.now
      tags = options[:tag] ? options[:tag].split(',') : []
      response = Sender.post(
        "#{Sender.base_uri}/create",
        body: { start_time: start_time, tags: tags  }.to_json,
        headers: headers
      )
      # Handle the response...
      if response.success?
        puts "学習セッションの開始に成功しました。"
      else
        error_message = response.parsed_response['error'] || response.parsed_response['message'] || 'Unknown error'
        puts "Error: #{response['error']}"
      end
    end

    desc "finish", "学習セッションの終了時間を記録します。"
    def finish
      finish_time = Time.now
      response = Sender.post(
        "#{Sender.base_uri}/update",
        body: { finish_time: finish_time }.to_json,
        headers: headers
      )
      # Handle the response...
      if response.success?
        puts "学習の終了時間を記録します。"
      else
        error_message = response.parsed_response['message'] || 'Unknown error'
        puts "Error: #{error_message}"
      end

    end

    desc "show_token", "保存されているトークンを表示します。"
    def show
      if File.exist?(CONFIG_FILE)
        config = JSON.parse(File.read(CONFIG_FILE))
        puts "現在のCUSTOM_TOKEN: #{config['CUSTOM_TOKEN'] || '未設定'}"
      else
        puts "トークンは未設定です。"
      end
    end

    private

    def user_token
      if File.exist?(CONFIG_FILE)
        config = JSON.parse(File.read(CONFIG_FILE))
        config['CUSTOM_TOKEN'] || (raise "Error: Token not found.")
      else
        raise "Error: Token not found."
      end
    end


    def headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{user_token}"
      }
    end
  end
end