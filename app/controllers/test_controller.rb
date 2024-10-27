class TestController < ApplicationController
  def test
    url = "https://www.google.com"
    html = Puptest.new.fetch_content(url)

    render plain: html.inspect
  end


  private
end
