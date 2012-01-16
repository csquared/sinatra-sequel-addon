require 'bundler'
Bundler.require

STDOUT.sync = true

DB = Sequel.connect ENV['DATABASE_URL']
Resource = DB[:resources]

class App < Sinatra::Base
  use Rack::Session::Cookie, secret: ENV['SSO_SALT']

  helpers do
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && 
      @auth.credentials == [ENV['HEROKU_USERNAME'], ENV['HEROKU_PASSWORD']]
    end

    def show_request
      body = request.body.read
      unless body.empty?
        STDOUT.puts "request body:"
        STDOUT.puts(@json_body = JSON.parse(body))
      end
      unless params.empty?
        STDOUT.puts "params: #{params.inspect}"
      end
    end

    def json_body
      @json_body || (body = request.body.read && JSON.parse(body))
    end

    def get_resource(id)
      Resource[:id => id] or halt 404, 'resource not found'
    end
  end
  
  # sso landing page
  get "/" do
    halt 403, 'not logged in' unless session[:heroku_sso]
    #response.set_cookie('heroku-nav-data', value: session[:heroku_sso])
    @resource = get_resource(session[:resource])
    @email    = session[:email]
    haml :index
  end

  def sso
    pre_token = params[:id] + ':' + ENV['SSO_SALT'] + ':' + params[:timestamp]
    token = Digest::SHA1.hexdigest(pre_token).to_s
    halt 403 if token != params[:token]
    halt 403 if params[:timestamp].to_i < (Time.now - 2*60).to_i

    halt 404 unless session[:resource]   = params[:id]

    response.set_cookie('heroku-nav-data', value: params['nav-data'])
    session[:heroku_sso] = params['nav-data']
    session[:email]      = params[:email]

    redirect '/'
  end
  
  # sso sign in
  get "/heroku/resources/:id" do
    show_request
    sso
  end

  post '/sso/login' do
    puts params.inspect
    sso
  end

  # provision
  post '/heroku/resources' do
    show_request
    protected!
    status 201
    id = Resource.insert(:plan => json_body.fetch('plan', 'test'))
    {id: id, config: {"MYADDON_URL" => 'http://user.yourapp.com/' + id.to_s}}.to_json
  end

  # deprovision
  delete '/heroku/resources/:id' do
    show_request
    protected!
    get_resource(params[:id])
    puts Resource.filter(:id => params[:id]).delete
    "ok"
  end

  # plan change
  put '/heroku/resources/:id' do
    show_request
    protected!  
    get_resource(params[:id]) 
    Resource.filter(:id => params[:id]).update(:plan => json_body['plan'])
    "ok"
  end
end
