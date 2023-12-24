# frozen_string_literal: true

require 'thor'
require 'httparty'

module StudyLine
  class CLI < Thor
    class Sender
      include HTTParty
      BASE_URI = 'https://studyline-cc21ae1829fc.herokuapp.com/dashboard/'
      # BASE_URI = 'http://localhost:3000/dashboard'
    end
    desc "start", "学習セッションの開始時間を記録します。"
    method_option :tag, aliases: "-t", desc: "タグを作成オプション"
    def start
      start_time = Time.now
      tags = options[:tag] ? options[:tag].split(',') : []
      response = Sender.post(
        "#{Sender::BASE_URI}/start",
        body: { start_time: start_time, tags: tags  }.to_json,
        headers: headers
      )
      # Handle the response...
      if response.success?
        puts "学習セッションの開始に成功しました。"
      else
        puts "Error: #{response['error']}"
      end
    end

    desc "finish", "学習セッションの終了時間を記録します。"
    def finish
      finish_time = Time.now
      response = Sender.post(
        "#{Sender::BASE_URI}/finish",
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