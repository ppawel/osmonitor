require 'test_helper'

class BrowseControllerTest < ActionController::TestCase
  test "should get road" do
    get :road
    assert_response :success
  end

end
