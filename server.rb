require 'rack'
require 'time'
require 'securerandom'
require 'json'
require 'digest'

TOKEN = (ENV["TOKEN"] || IO.read("token") rescue "").strip
SERVER_RAND = SecureRandom.hex(16)

class App
  def call(env)
    req = Rack::Request.new(env)

    case req.path
    when '/'
      [200, {'Content-Type' => 'text/html'}, [File.read('index.html')]]
    when '/styles.css'
      [200, {'Content-Type' => 'text/css'}, [File.read('styles.css')]]
    when '/script.js'
      [200, {'Content-Type' => 'text/javascript'}, [File.read('script.js')]]
    when '/dancing-baby.gif'
      [200, {'Content-Type' => 'image/gif'}, [File.read('dancing-baby.gif')]]
    when '/upload'
      handle_upload(req)
    when '/auth'
      handle_auth(req)
    else
      [404, {'Content-Type' => 'text/plain'}, ['Not found']]
    end
  end

  def handle_auth(req)
    token = (ENV["TOKEN"] || IO.read("token") rescue "").strip

    if token.length > 0 && req.params['token'] != token
      log_upload(req, req.params['filename'], req.params['filesize'], req.env['HTTP_X_FORWARDED_FOR'] || req.ip, "Invalid token \"#{req.params['token']}\"")
      return [403, {'Content-Type' => 'text/plain'}, ['Invalid token']]
    end

    filename = req.params['filename']
    size = req.params['filesize']
    auth_str = "#{filename}::#{size}::#{token}::#{SERVER_RAND}"
    auth_code = Digest::SHA256.hexdigest(auth_str)
    log_upload(req, filename, size, req.env['HTTP_X_FORWARDED_FOR'] || req.ip, "Auth code: #{auth_code}")
    [200, {'Content-Type' => 'application/json'}, [{'auth': auth_code}.to_json]]
  end


  def handle_upload(req)
    tempfile = req.params['file'][:tempfile]
    ip_address = req.env['HTTP_X_FORWARDED_FOR'] || req.ip
    filename = sanitize_filename(req.params['file'][:filename])
    auth = req.params['auth']

    expected_digest = Digest::SHA256.hexdigest("#{filename}::#{tempfile.size}::#{TOKEN}::#{SERVER_RAND}")

    if auth != expected_digest then
      return [403, {'Content-Type' => 'text/plain'}, ['Invalid auth']]
    end

    log_upload(req, filename, tempfile.size, ip_address, "Begin file upload")

    Dir.mkdir('upload') unless Dir.exist?('upload')
    path = File.join('upload', filename)

    File.open(path, 'wb') do |file|
      while chunk = tempfile.read(1024*1024) do
        file.write(chunk)
      end
    end

    log_upload(req, filename, File.size(path), ip_address, "End file upload")
    [200, {'Content-Type' => 'text/plain'}, ['File uploaded']]
  end

  def sanitize_filename(filename)
    forbidden = "/*\x00$`'\""

    forbidden.each_char do |forbidden_char|
      filename.gsub!(forbidden_char, '_')
    end

    filename = filename.gsub(/^\./, '_')
    filename
  end

  def log_upload(req, filename, size, ip_address, status)
    time = Time.now

    File.open('uploads.log', 'a') do |file|
      file.puts("#{time} #{ip_address} #{status}, name=\"#{filename}\", size=#{size}")
    end
  end
end

Rack::Handler::WEBrick.run App.new, Host: '0.0.0.0', :Port => 8080
