require 'rest-client'
require 'json'
require 'yaml'
require 'telegramAPI'

def init
  @HOST_ADDRESS, @HOST_PORT, @DELEGATE_NAME, @TELEGRAM_ID, @TELEGRAM_API_KEY, @RANK_FILE = YAML.load(File.read("config.yaml"))
  @telegramAPI = TelegramAPI.new(@TELEGRAM_API_KEY)
  save_rank(get_rank) unless File.file?(@RANK_FILE)
end

def rest_request(destination, port, path, method, payload = '')
  RestClient::Request.new(
    :method => method,
    :url => "#{destination}:#{port}/#{path}",
    :payload => payload,
    :headers => {:content_type => "application/xml"},
    :verify_ssl => OpenSSL::SSL::VERIFY_NONE
  ).execute {|resp|
    return resp
  }
end

def save_rank(rank)
  File.open(@RANK_FILE, 'w') { |file| file.write(get_rank) }
end

def get_rank_from_file
  File.read(@RANK_FILE)
end

def get_rank
  path = "api/delegates/get?username=#{@DELEGATE_NAME}"
  delegate_hash = JSON.parse(rest_request(@HOST_ADDRESS,@HOST_PORT,path,:get))["delegate"]
  delegate_hash["rate"]
end

def send_to_telegram(msg)
  @telegramAPI.sendMessage(@TELEGRAM_ID, msg)
end

def check_rank
  current_rank = get_rank
  previous_rank = get_rank_from_file
  rank_difference = previous_rank.to_i - current_rank
  if rank_difference != 0
    msg = "Shiftux currently is on rank: #{get_rank}\n previous rank: #{previous_rank} change: #{rank_difference}"
    send_to_telegram(msg)
    save_rank(current_rank)
  end
end

init
check_rank