# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onebox::Helpers do
  describe '.blank?' do
    it { expect(described_class.blank?("")).to be(true) }
    it { expect(described_class.blank?(" ")).to be(true) }
    it { expect(described_class.blank?("test")).to be(false) }
    it { expect(described_class.blank?(["test", "testing"])).to be(false) }
    it { expect(described_class.blank?([])).to be(true) }
    it { expect(described_class.blank?({})).to be(true) }
    it { expect(described_class.blank?(nil)).to be(true) }
    it { expect(described_class.blank?(true)).to be(false) }
    it { expect(described_class.blank?(false)).to be(true) }
    it { expect(described_class.blank?(a: 'test')).to be(false) }
  end

  describe ".truncate" do
    let(:test_string) { "Chops off on spaces" }
    it { expect(described_class.truncate(test_string)).to eq(test_string) }
    it { expect(described_class.truncate(test_string, 5)).to eq("Chops...") }
    it { expect(described_class.truncate(test_string, 7)).to eq("Chops...") }
    it { expect(described_class.truncate(test_string, 9)).to eq("Chops off...") }
    it { expect(described_class.truncate(test_string, 10)).to eq("Chops off...") }
    it { expect(described_class.truncate(test_string, 100)).to eq("Chops off on spaces") }
    it { expect(described_class.truncate(" #{test_string} ", 6)).to eq(" Chops...") }
  end

  describe "fetch_response" do
    after(:each) do
      Onebox.options = Onebox::DEFAULTS
    end

    before do
      Onebox.options = { max_download_kb: 1 }
      fake("http://example.com/large-file", response("slides"))
    end

    it "raises an exception when responses are larger than our limit" do
      expect {
        described_class.fetch_response('http://example.com/large-file')
      }.to raise_error(Onebox::Helpers::DownloadTooLarge)
    end
  end

  describe "fetch_html_doc" do
    it "can handle unicode URIs" do
      uri = 'https://www.reddit.com/r/UFOs/comments/k18ukd/𝗨𝗙𝗢_𝗱𝗿𝗼𝗽𝘀_𝗰𝗼𝘄_𝘁𝗵𝗿𝗼𝘂𝗴𝗵_𝗯𝗮𝗿𝗻_𝗿𝗼𝗼𝗳/'
      fake(uri, "<!DOCTYPE html><p>success</p>")

      expect(described_class.fetch_html_doc(uri).to_s).to match("success")
    end
  end

  describe "redirects" do
    describe "redirect limit" do
      before do
        (1..6).each do |i|
          FakeWeb.register_uri(:get, "https://httpbin.org/redirect/#{i}", location: "https://httpbin.org/redirect/#{i - 1}", body: "", status: [302, "Found"])
        end
        fake("https://httpbin.org/redirect/0", "<!DOCTYPE html><p>success</p>")
      end

      it "can follow redirects" do
        expect(described_class.fetch_response("https://httpbin.org/redirect/2")).to match("success")
      end

      it "errors on long redirect chains" do
        expect {
          described_class.fetch_response("https://httpbin.org/redirect/6")
        }.to raise_error(Net::HTTPError, /redirect too deep/)
      end
    end

    describe "cookie handling" do
      it "naively forwards cookies to the next request" do
        FakeWeb.register_uri(:get, "https://httpbin.org/cookies/set/a/b",
                             location: "/cookies",
                             'set-cookie': "a=b; Path=/",
                             status: [302, "Found"])
        fake("https://httpbin.org/cookies", "success, cookie readback not implemented")

        expect(described_class.fetch_response('https://httpbin.org/cookies/set/a/b')).to match("success")
        expect(FakeWeb.last_request.to_hash['cookie'][0]).to match("a=b")
      end

      it "does not send cookies to the wrong domain" do
        skip("unimplemented")

        FakeWeb.register_uri(:get, "https://httpbin.org/cookies/set/a/b",
                             location: "https://evil.com/show_cookies",
                             'set-cookie': "a=b; Path=/",
                             status: [302, "Found"])
        fake("https://evil.com/show_cookies", "success, cookie readback not implemented")

        described_class.fetch_response('https://httpbin.org/cookies/set/a/b')
        expect(FakeWeb.last_request.to_hash['cookie']).to be_nil
      end
    end
  end

  describe "user_agent" do
    before do
      fake("http://example.com/some-resource", body: 'test')
    end

    context "default" do
      it "has the Ruby user agent" do
        described_class.fetch_response('http://example.com/some-resource')
        expect(FakeWeb.last_request.to_hash['user-agent'][0]).to eq("Ruby")
      end
    end

    context "Custom option" do
      after(:each) do
        Onebox.options = Onebox::DEFAULTS
      end

      before do
        Onebox.options = { user_agent: "EvilTroutBot v0.1" }
      end

      it "has the custom user agent" do
        described_class.fetch_response('http://example.com/some-resource')
        expect(FakeWeb.last_request.to_hash['user-agent'][0]).to eq("EvilTroutBot v0.1")
      end
    end
  end

  describe '.normalize_url_for_output' do
    it { expect(described_class.normalize_url_for_output('http://example.com/fo o')).to eq("http://example.com/fo%20o") }
    it { expect(described_class.normalize_url_for_output("http://example.com/fo'o")).to eq("http://example.com/fo&apos;o") }
    it { expect(described_class.normalize_url_for_output('http://example.com/fo"o')).to eq("http://example.com/fo&quot;o") }
    it { expect(described_class.normalize_url_for_output('http://example.com/fo<o>')).to eq("http://example.com/foo") }
    it { expect(described_class.normalize_url_for_output('http://example.com/d’écran-à')).to eq("http://example.com/d’écran-à") }
    it { expect(described_class.normalize_url_for_output('//example.com/hello')).to eq("//example.com/hello") }
    it { expect(described_class.normalize_url_for_output('example.com/hello')).to eq("") }
    it { expect(described_class.normalize_url_for_output('linear-gradient(310.77deg, #29AA9F 0%, #098EA6 100%)')).to eq("") }
  end

  describe '.uri_encode' do
    it { expect(described_class.uri_encode('http://example.com/f"o&o?[b"ar]')).to eq("http://example.com/f%22o&o?%5Bb%22ar%5D") }
    it { expect(described_class.uri_encode("http://example.com/f.o~o;?<ba'r>")).to eq("http://example.com/f.o~o;?%3Cba%27r%3E") }
    it { expect(described_class.uri_encode("http://example.com/<pa'th>(foo)?b+a+r")).to eq("http://example.com/%3Cpa'th%3E(foo)?b%2Ba%2Br") }
    it { expect(described_class.uri_encode("http://example.com/p,a:t!h-f$o@o*?b!a#r@")).to eq("http://example.com/p,a:t!h-f$o@o*?b%21a#r%40") }
    it { expect(described_class.uri_encode("http://example.com/path&foo?b'a<r>&qu(er)y=1")).to eq("http://example.com/path&foo?b%27a%3Cr%3E&qu%28er%29y=1") }
    it { expect(described_class.uri_encode("http://example.com/index&<script>alert('XSS');</script>")).to eq("http://example.com/index&%3Cscript%3Ealert('XSS');%3C/script%3E") }
    it { expect(described_class.uri_encode("http://example.com/index.html?message=<script>alert('XSS');</script>")).to eq("http://example.com/index.html?message=%3Cscript%3Ealert%28%27XSS%27%29%3B%3C%2Fscript%3E") }
    it { expect(described_class.uri_encode("http://example.com/index.php/<IFRAME SRC=source.com onload='alert(document.cookie)'></IFRAME>")).to eq("http://example.com/index.php/%3CIFRAME%20SRC=source.com%20onload='alert(document.cookie)'%3E%3C/IFRAME%3E") }
    it { expect(described_class.uri_encode("https://en.wiktionary.org/wiki/greengrocer%27s_apostrophe")).to eq("https://en.wiktionary.org/wiki/greengrocer%27s_apostrophe") }

    it { expect(described_class.uri_encode("https://example.com/random%2Bpath?q=random%2Bquery")).to eq("https://example.com/random%2Bpath?q=random%2Bquery") }
    it { expect(described_class.uri_encode("https://glitch.com/edit/#!/equinox-watch")).to eq("https://glitch.com/edit/#!/equinox-watch") }
    it { expect(described_class.uri_encode("https://gitpod.io/#https://github.com/eclipse-theia/theia")).to eq("https://gitpod.io/#https://github.com/eclipse-theia/theia") }
  end
end
