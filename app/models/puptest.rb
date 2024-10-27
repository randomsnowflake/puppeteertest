class Puptest
  # Ruby Script for Web Content Extraction
  #
  # loads the page in puppetteer and extracts the content with readability.js
  # returns "" on error or when not a html file


  def fetch_content(url)
    # return FetchFeedMasterdataJob.fetch_page(url, true)

    Rails.logger.info "[ExtractContent] Starting content extraction for URL: #{url}"
    start_time = Time.now

    execute_with_suppressed_logging do |browser|
      Rails.logger.info "[ExtractContent] Browser launched successfully after #{(Time.now - start_time).round(2)}s"

      browser_session(browser, url) do |page, context|
        Rails.logger.info "[ExtractContent] Browser session created after #{(Time.now - start_time).round(2)}s"

        setup_page(page)
        Rails.logger.info "[ExtractContent] Page setup completed after #{(Time.now - start_time).round(2)}s"

        content = extract_content(browser, page, url)
        Rails.logger.info "[ExtractContent] Content extracted after #{(Time.now - start_time).round(2)}s"

        return content
      end
    end
  rescue => e
    Rails.logger.error "[ExtractContent] Failed after #{(Time.now - start_time).round(2)}s"
    Rails.logger.error "[ExtractContent] Error: #{e.class} - #{e.message}"
    Rails.logger.error "[ExtractContent] Backtrace:\n#{e.backtrace.join("\n")}"
    ""
  end

  private

  def setup_page(page)
    Rails.logger.info "[ExtractContent] Setting up page..."
    page.javascript_enabled = true

    width = rand(1024..1920)
    height = rand(768..1080)
    page.viewport = Puppeteer::Viewport.new(width: width, height: height)
    Rails.logger.info "[ExtractContent] Viewport set to #{width}x#{height}"
  end

  def execute_with_suppressed_logging
    Rails.logger.info "[ExtractContent] Launching browser with options..."
    options = {
      executable_path: ENV["CHROME_PATH"],
      args: [
        "--disable-http2",
        "--no-sandbox",
        "--disable-dev-shm-usage", # Add this for Docker environments
        "--disable-gpu", # Add this for headless environments
        "--headless" # Make sure we're running headless
      ]
    }
    Rails.logger.info "[ExtractContent] Chrome path: #{ENV['CHROME_PATH']}"

      # suppress_logging do
      Puppeteer.launch(**options) do |browser|
        Rails.logger.info "[ExtractContent] Browser launched successfully"
        yield(browser)
        Rails.logger.info "[ExtractContent] After yield, Browser session finished"
      end
    # end
  end

  def browser_session(browser, url)
    Rails.logger.info "[ExtractContent] Creating new browser context..."
    context = browser.default_browser_context
    page = context.new_page

    Rails.logger.info "[ExtractContent] Setting page timeouts to 20,000ms"
    page.default_navigation_timeout = 20_000
    page.default_timeout = 20_000

    yield(page, context)
  rescue => e
    Rails.logger.error "[ExtractContent] Browser session failed: #{e.message}"
    raise
  ensure
    Rails.logger.info "[ExtractContent] Cleaning up browser session..."
    page&.close rescue Rails.logger.error("[ExtractContent] Failed to close page")
    context&.close rescue Rails.logger.error("[ExtractContent] Failed to close context")
  end

  def extract_content(browser, page, url)
    Rails.logger.info "[ExtractContent] Navigating to URL..."
    navigation_start = Time.now
    page.goto(url, wait_until: "networkidle2", timeout: 20_000)
    Rails.logger.info "[ExtractContent] Navigation completed in #{(Time.now - navigation_start).round(2)}s"

    content = page.content
    Rails.logger.info "[ExtractContent] Content extraction complete"
    content
  end

  def handle_ip_blocks(content)
    if is_blocked_by_cloudfare?(content)
      Rails.logger.warn "[ExtractContent] Detected Cloudflare block"
      return "-"
    end

    if is_blocked_by_reddit?(content)
      Rails.logger.warn "[ExtractContent] Detected Reddit block"
      return "-"
    end

    content
  end

  def is_blocked_by_cloudfare?(content)
    block_terms = [
      "<p>The owner of this website",
      "has banned your access based on your browser's signature",
      "<p>Ray ID: ",
      "<span>Ray ID: ",
      '<span data-translate="error">Error</span>',
      "has banned the autonomous system number (ASN) your IP address",
      "has banned your access based on your browser's signature",
      '<span><span>Performance &amp; security by</span> <a rel="noopener noreferrer" href="https://www.cloudflare.com'
    ]

    # return true if any of the blockterms exist in the string content
    block_terms.any? { |term| content.include?(term) }
  end

  def is_blocked_by_reddit?(content)
    block_terms = [
      "if you think that we've incorrectly blocked you or you would like to discuss",
      "Your request has been blocked due to a network policy",
      'Try logging in or creating an account <a href="https://www.reddit.com/login/">here</a> to get back to browsing'
    ]

    # return true if any of the blockterms exist in the string content
    block_terms.any? { |term| content.include?(term) }
  end

  def suppress_logging
    original_stderr = STDERR.clone
    STDERR.reopen(File.new("/dev/null", "w"))
    yield
  ensure
    STDERR.reopen(original_stderr)
  end
end

# Replace 'http://example.com' with the actual URL you want to process
# result = extract_content_with_node('http://example.com')
# puts result.is_a?(Hash) && result.key?('error') ? result : result['content']
