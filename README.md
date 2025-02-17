onebox
======

[![Gem Version](https://badge.fury.io/rb/onebox.svg)](https://rubygems.org/gems/onebox)
[![Code Climate](https://codeclimate.com/github/dysania/onebox.svg)](https://codeclimate.com/github/dysania/onebox)
[![Build Status](https://travis-ci.org/discourse/onebox.svg)](https://travis-ci.org/discourse/onebox)

Onebox is a library for turning media URLs into simple HTML previews of the resource.

Onebox currently has support for page, image, and video URLs for many popular sites.

It's great if you want users to input URLs and have your application convert them into
rich previews for display. For example, a link to a Google video would be automatically
converted into a video player.

It was originally created for [Discourse](http://discourse.org) but has since been
extracted into this convenient gem for all to use!

Usage
-----

Using onebox is fairly simple!
First, make sure the library is required:

``` ruby
require "onebox"
```

Then pass a link to the library's interface:

``` ruby
require "onebox"

url = "http://www.amazon.com/gp/product/B005T3GRNW/ref=s9_simh_gw_p147_d0_i2"
preview = Onebox.preview(url)
```

This will contain a simple Onebox::Preview object that handles all the transformation.
From here you either call `Onebox::Preview#to_s` or just pass the object to a string:

``` ruby
require "onebox"

url = "http://www.amazon.com/gp/product/B005T3GRNW/ref=s9_simh_gw_p147_d0_i2"
preview = Onebox.preview(url)
"#{preview}" == preview.to_s #=> true
```

### Twitch Onebox

To be able to embed Twitch video and clips, pass `hostname` in the options to `Onebox.preview`

```ruby
preview = Onebox.preview(url, hostname: 'www.example.com')
```

Ruby Support
------------

The onebox library is supported on all "officially" supported versions of Ruby.

This means you must be on Ruby 2.4 or above for it to work.

Development Preview Interface
-----------------------------

The onebox gem comes with a development server for previewing the results
of your changes. You can run it by running `bundle exec rake server` after checking
out the project. You can then try out URLs.

The server doesn't reload code changes automatically (PRs accepted!) so
make sure to hit CTRL-C and restart the server to try a code change out.

Adding Support for a new URL
----------------------------

  1. Check if the site supports [oEmbed](http://oembed.com/) or [Open Graph](https://developers.facebook.com/docs/opengraph/).
     If it does, you can probably get away with just allowing the URL in `Onebox::Engine::AllowlistedGenericOnebox` (see: [Allowlisted Generic Onebox caveats](#user-content-allowlisted-generic-onebox-caveats)).
     If the site does not support open standards, you can create a new engine.

  2. Create new onebox engine

     ``` ruby
     # in lib/onebox/engine/name_onebox.rb

     module Onebox
       module Engine
         class NameOnebox
           include LayoutSupport
           include HTML

           private

           def data
             {
               url: @url,
               name: communication("h1").inner_text,
               image: communication("#main-image").first["src"],
               description: communication ("#Developing-skills").inner_text
             }
           end
         end
       end
     end
     ```

  3. Create new onebox spec using [FakeWeb](https://github.com/chrisk/fakeweb)

     ``` ruby
     # in spec/lib/onebox/engine/name_spec.rb
     require "spec_helper"

     describe Onebox::Engine::NameOnebox do
       let(:link) { "http://example.com" }
       let(:html) { described_class.new(link).to_html }

       before do
         fake(link, response("name"))
       end

       it "has the video's title" do
         expect(html).to include("title")
       end

       it "has the video's still shot" do
         expect(html).to include("photo.jpg")
       end

       it "has the video's description" do
         expect(html).to include("description")
       end

       it "has the URL to the resource" do
         expect(html).to include(link)
       end
     end
     ```

  4. Create new mustache template

     ``` html
     # in templates/name.mustache
     <div class="onebox">
       <a href="{{url}}">
         <h1>{{name}}</h1>
         <h2 class="host">example.com</h2>
         <img src="{{image}}" />
         <p>{{description}}</p>
       </a>
     </div>
     ```

  5. Create new fixture from HTML response for your FakeWeb request(s)

     ``` bash
     curl --output spec/fixtures/oneboxname.response -L -X GET http://example.com
     ```

  6. Require in Engine module

     ``` ruby
     # in lib/onebox/engine.rb
     require_relative "engine/name_onebox"
     ```

Allowlisted Generic Onebox caveats
----------------------------------

The Allowlisted Generic Onebox has some caveats for its use, beyond simply allowlisting the domain.

  1. The domain must be allowlisted
  2. The URL you're oneboxing cannot be a root url (e.g. `http://example.com` won't work, but `http://example.com/page` will)
  3. If the oneboxed URL responds with oEmbed and has a `rich` type: the `html` content must contain an `<iframe>`. Responses without an iframe will not be oneboxed.

Ignoring Canonical URLs
-----------------------

Onebox prefers to use canonical URLs instead of the raw inputted URL when searching for Open Graph metadata. If your site's canonical URL does not have opengraph metadata, use the `og:ignore_canonical` property to have Onebox ignore the canonical URL.

```html
<meta property="og:ignore_canonical" content="true" />
```

Installing
----------

Add this line to your application's Gemfile:

    gem "onebox"

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install onebox


Issues / Discussion
-------------------

Discussion of the Onebox gem, its development and features should be done on
[Discourse Meta](https://meta.discourse.org).

Contributing
------------

  1. Fork it
  2. Create your feature branch (`git checkout -b my-new-feature`)
  3. Commit your changes (`git commit -am 'Add some feature'`)
  4. Push to the branch (`git push origin my-new-feature`)
  5. Create new Pull Request
