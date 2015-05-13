require 'tiny_tds'
require 'viaduct/webpush'
require 'yaml'

config = YAML.load_file(File.expand_path('../config.yml', __FILE__))

Viaduct::WebPush.token = config['webpush_token']
Viaduct::WebPush.secret = config['webpush_secret']

client = TinyTds::Client.new(:username => config['database_username'], :password => config['database_password'], :host => config['database_host'], :port => config['database_port'], :database => config['database_name'])

last_id_result = client.execute("SELECT UNIQUE_ID FROM [EVENT_LOG] ORDER BY UNIQUE_ID DESC")
if last_id = last_id_result.first
  last_id = last_id['UNIQUE_ID']
  last_id_result.do
else
  puts "can't get last id"
  Process.exit(1)
end

query = "select [ID], [NAME] from [dbo].[KEYHOLDER]"
keyholder_result = client.execute(query)
keyholders = {}
keyholder_result.each do |kh|
  keyholders[kh['ID']] = kh['NAME']
end
keyholder_result.do

doors = {212 => 'Upstairs', 335 => 'Downstairs'}

loop do
  begin
    query = "select * from [dbo].[EVENT_LOG] where [UNIQUE_ID] > '#{last_id}' AND [EVENT_ID] = '2001' "
    events_result = client.execute(query)
    events = events_result.to_a
    events_result.do
    for event in events
      door_id = event['ID_1']
      keyholder_id = event['ID_3']

      keyholder = keyholders[keyholder_id.to_i]
      door = doors[door_id.to_i]

      puts "#{keyholder} arrived at #{door}"

      Viaduct::WebPush['access'].trigger('entry', {
        :keyholder => keyholder,
        :door => door,
        :time => event['LOCAL_TIME'],
        :id => event['ID'],
        :site => event['SITE_ID']
      })

      last_id = event['UNIQUE_ID']
    end
  rescue => e
    puts e.class
    puts e.message
  end
  sleep 1
end
