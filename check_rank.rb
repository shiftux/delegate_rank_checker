require 'rest-client'
require 'json'
require 'yaml'
require 'telegramAPI'
require 'socket'
require 'csv'

def init
  @HOST_ADDRESS, @HOST_PORT, @DELEGATE_NAME, @SHIFTUX_PUBLIC_KEY, @TELEGRAM_ID, @TELEGRAM_API_KEY, @RANK_FILE, @VOTERS_FILE = YAML.load(File.read("config.yaml"))
  @telegramAPI = TelegramAPI.new(@TELEGRAM_API_KEY)
  save_rank(get_rank) unless File.file?(@RANK_FILE)
  save_voters unless File.file?(@VOTERS_FILE)
  @HOST_ADDRESS = 'https://127.0.0.1' if Socket.gethostname == 'shiftux'
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

def save_voters
  CSV.open(@VOTERS_FILE, "w") do |csv|
    csv << ["username", "address", "publicKey", "balance"]
    get_delegates.each { |l|
      csv << l.values
    }
  end
end

def get_rank_from_file
  File.read(@RANK_FILE)
end

def get_voters_from_file
  out = []
  CSV.foreach(@VOTERS_FILE, headers: true) do |row|
    out << row.to_hash
  end
  return out
end

def get_rank
  path = "api/delegates/get?username=#{@DELEGATE_NAME}"
  delegate_hash = JSON.parse(rest_request(@HOST_ADDRESS,@HOST_PORT,path,:get))["delegate"]
  delegate_hash["rate"]
end

def get_delegates
  path = "api/delegates/voters?publicKey=#{@SHIFTUX_PUBLIC_KEY}"
  delegate_hash = JSON.parse(rest_request(@HOST_ADDRESS,@HOST_PORT,path,:get))["accounts"]
  return delegate_hash
end

def find_new_voters
  new_voters = get_delegates
  get_voters_from_file.each do |previous_voter|
    new_voters.reject!{ |current_voter| current_voter["address"] == previous_voter["address"] }
  end
  new_voters
end

def find_removed_voters
  previous_voters = get_voters_from_file
  get_delegates.each do |current_voter|
    previous_voters.reject!{ |previous_voter| current_voter["address"] == previous_voter["address"] }
  end
  previous_voters
end

def send_to_telegram(msg)
  @telegramAPI.sendMessage(@TELEGRAM_ID, msg)
end

def check_rank
  current_rank = get_rank
  previous_rank = get_rank_from_file
  rank_difference = previous_rank.to_i - current_rank
  msg = ""
  if rank_difference != 0
    msg = msg + "Shiftux currently is on rank: #{get_rank}\n previous rank: #{previous_rank} change: #{rank_difference}\n\n"
    save_rank(current_rank)
  end
  msg
end

def compare_voters
  new_voters = find_new_voters
  no_longer_voters = find_removed_voters
  msg = ""
  unless new_voters.empty?
    msg = msg + "New delegates voting for shiftux: \n"
    msg = msg + new_voters.map{|new_voter| " - "+new_voter["username"]+" "+new_voter["address"]}.join("\n")+"\n"
  end
  unless no_longer_voters.empty?
    msg = msg + "Delegates no longer voting for shiftux: \n"
    msg = msg + no_longer_voters.map{|nlv| " - "+nlv["username"]+" "+nlv["address"]}.join("\n")+"\n"
  end
  save_voters
  msg
end

def main
  init
  msg = check_rank + compare_voters
  send_to_telegram(msg) unless msg.empty?
end

main
