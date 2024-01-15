# frozen_string_literal: true

require 'thor'
require 'httparty'
require 'dotenv'
Dotenv.load

module StudyLine
  class CLI < Thor
      desc "configure TOKEN", "トークンを設定します。"
      def configure(token)
        File.open('.env', 'w') do |file|
          file.puts "CUSTOM_TOKEN=#{token}"
        end
        puts "トークンが設定されました。"
      end

    class Sender
      include HTTParty
      # BASE_URI = 'https://studyline-cc21ae1829fc.herokuapp.com/api/study_sessions'
      BASE_URI = 'http://localhost:3000/api/study_sessions'
    end
    desc "start", "学習セッションの開始時間を記録します。"
    method_option :tag, aliases: "-t", desc: "タグを作成オプション"
    def start
      start_time = Time.now
      tags = options[:tag] ? options[:tag].split(',') : []
      response = Sender.post(
        "#{Sender::BASE_URI}/create",
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
        "#{Sender::BASE_URI}/update",
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
      puts "現在のCUSTOM_TOKEN: #{ENV['CUSTOM_TOKEN'] || '未設定'}"
    end

    private

    def user_token
      ENV['CUSTOM_TOKEN'] || (raise "Error: Token not found.")
    end 

    def headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{user_token}"
      }
    end
  end
end