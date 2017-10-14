# app.rb
require 'sinatra'
require 'line/bot'
require 'dotenv'
require 'json'
require 'uri'
require 'net/http'

Dotenv.load

def client
  @client ||= Line::Bot::Client.new {|config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

def qna_maker(question)
  knowledgeBaseID = ENV['KB_ID']
  uri = URI("https://westus.api.cognitive.microsoft.com/qnamaker/v2.0/knowledgebases/#{knowledgeBaseID}/generateAnswer")

  request = Net::HTTP::Post.new(uri.request_uri)
  # Request headers
  request['Content-Type'] = 'application/json'
  # Request headers
  request['Ocp-Apim-Subscription-Key'] = ENV['OCP_APIM_SUBSCRIPTION_KEY']

  # Request body
  request.body = {question: question}.to_json

  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
    http.request(request)
  end

  puts response.body
  JSON.parse(response.body)
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do
      'Bad Request'
    end
  end

  events = client.parse_events_from(body)
  events.each { |event|
    case event
      when Line::Bot::Event::Message
        case event.type
          when Line::Bot::Event::MessageType::Text
            question = event.message['text']
            answers = qna_maker(question)['answers']
            answer = answers.first['answers']

            message = {
                type: 'text',
                text: answer
            }
            client.reply_message(event['replyToken'], message)
          when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
            response = client.get_message_content(event.message['id'])
            tf = Tempfile.open("content")
            tf.write(response.body)
        end
    end
  }

  "OK"
end