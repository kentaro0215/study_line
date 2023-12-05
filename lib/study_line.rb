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
    desc "start", "Record the start time of study"
    method_option :tag, aliases: "-t", desc: "Tag for the study session"
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
        puts "Study session started successfully."
      else
        puts "Error: #{response['error']}"
      end
    end

    desc "finish", "Record the finish time of study"
    def finish
      finish_time = Time.now
      response = Sender.post(
        "#{Sender::BASE_URI}/finish",
        body: { finish_time: finish_time }.to_json,
        headers: headers
      )
      # Handle the response...
      if response.success?
        puts "Study session started successfully."
      else
        error_message = response.parsed_response['error'] || 'Unknown error'
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