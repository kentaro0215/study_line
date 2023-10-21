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
      file_path = "/path/to/your/refresh_token.txt"  # Replace with the actual path to your refresh token file
      File.read(file_path).strip
    rescue Errno::ENOENT
      puts "Error: Token file not found."
      exit 1
    end

    def headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{refresh_token}"
      }
    end
  end
end
