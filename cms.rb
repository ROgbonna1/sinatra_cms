require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'redcarpet'
require 'psych'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def signed_in?
    session.key?(:username)
  end
  
  def verify_user
    unless signed_in?
      session[:message] = "You must be signed in to do that."
      redirect "/"
    end
  end
    
end

def valid_credentials?(username, password)
  credentials = load_user_credentials
  credentials.key?(username) && 
    BCrypt::Password.new(credentials[username]) == password
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path('../test/users.yml', __FILE__)
  else
    File.expand_path('../users.yml', __FILE__)
  end
  Psych.load_file(credentials_path)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  
  erb :index
end

get "/new" do
  verify_user
  
  erb :new
end

post "/new" do
  verify_user
  
  doc_name = params[:doc_name]
  existing_files = Dir.glob(File.join(data_path, "*")).map do |path|
    File.basename(path)
  end
  
  if doc_name.nil? || doc_name.strip.empty?
    session[:message] = "A name is required."
    status 422
    erb :new
  elsif existing_files.include? doc_name
    session[:message] = "A file already exists with the given name. Name must be unique."
    status 422
    erb :new
  else
    FileUtils.touch(File.join(data_path,doc_name))
    session[:message] = "#{doc_name} was created."
    redirect "/"
  end
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  if valid_credentials?(params[:username], params[:password])
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist? file_path
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  verify_user
  
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post "/:filename/delete" do
  verify_user
  
  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)
  session[:message] = "#{File.basename(file_path)} was deleted."
  redirect "/"
end

post "/:filename" do
  verify_user
  
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end
