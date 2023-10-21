# frozen_string_literal: true

require 'thor'
require 'httparty'

module StudyLine
  class CLI < Thor
    class Sender
      include HTTParty
      BASE_URI = 'https://your-web-app.com/api'
    end

    desc "start", "Record the start time of study"
    def start
      start_time = Time.now
      response = Sender.post(
        "#{Sender::BASE_URI}/start",
        body: { start_time: start_time }.to_json,
        headers: headers
      )
      # Handle the response...
    end

    desc "finish", "Record the finish time of study"
    def finish
      end_time = Time.now
      response = Sender.post(
        "#{Sender::BASE_URI}/finish",
        body: { end_time: end_time }.to_json,
        headers: headers
      )
      # Handle the response...
    end

    private

    def refresh_token
      file_path = "/path/to/your/refresh_token.txt"
      File.read(file_path).strip
    rescue Errno::ENOENT
      puts "Error: Token file not found."
      exit 1
    end

    def access_token
      file_path = "/path/to/your/access_token.txt"
      File.read(file_path).strip
    rescue Errno::ENOENT
      nil
    end

    def refresh_access_token
      new_access_token = get_new_access_token
      file_path = "/path/to/your/access_token.txt"
      
      File.open(file_path, 'w') do |file|
        file.write(new_access_token)
      end
    rescue => e
      puts "Failed to refresh access token: #{e.message}"
      exit 1
    end

    def get_new_access_token
      # ... code to obtain a new access token using the refresh token
    end

    def headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{access_token || refresh_access_token}"
      }
    end
  end
end
