ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
  
  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
  
  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end
  
  def admin_session
    { "rack.session" => { username: "admin" } }
  end
  
  def session
    last_request.env["rack.session"]
  end

  def test_index
    create_document("about.md")
    create_document("changes.txt")
    
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"

  end

  def test_viewing_text_document
    create_document("history.txt", "This is a peoples' history of the US.")
    
    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "This is a peoples' history"
  end
  
  def test_document_not_found
    get "/notafile.ext" # Attempt to access a nonexistent file
  
    assert_equal 302, last_response.status # Assert that the user was redirected
    
    assert_includes session[:message], "does not exist"
  
    get "/" # Reload the page
    assert_nil session[:message] # Assert that our message has been removed
  end
  
  def test_viewing_markdown_document
    create_document("about.md")
    File.write(File.join(data_path,"about.md"), '**This is a markdown document.**')
    
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<strong>"
  end
  
  def test_editing_document
    create_document("changes.txt")
    
    get "/changes.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get "/changes.txt/edit", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/changes.txt", content: "new content"
    assert_equal 302, last_response.status
    assert_equal session[:message], "You must be signed in to do that."
    
    post "/changes.txt", {content: "new content"}, admin_session
    assert_includes session[:message], "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
  
  def test_creating_document
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    
    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "</form>"
    
    post "/new", doc_name: "test.txt"
    assert_equal 302, last_response.status
    
    existing_files = Dir.glob(File.join(data_path, "*")).map do |path|
      File.basename(path)
    end
    
    assert_includes existing_files, "test.txt" 
    assert_includes session[:message], "test.txt was created"
  end
  
  def test_deleting_document
    create_document("test.txt")
    
    post "/test.txt/delete"
    assert_equal "You must be signed in to do that.", session[:message]
    assert_equal 302, last_response.status
    
    post "/test.txt/delete", {}, admin_session
    assert_includes session[:message], "test.txt was deleted"

    existing_files = Dir.glob(File.join(data_path, "*")).map do |path|
      File.basename(path)
    end
    
    refute_includes existing_files, "text.txt"
  end
  
  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    
    assert_includes session[:message], "Welcome"
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin" } } # get request to the index page loading username: admin to the session
    assert_includes last_response.body, "Signed in as admin"
    
    post "/users/signout"
    assert_includes session[:message], "You have been signed out"
    
    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end